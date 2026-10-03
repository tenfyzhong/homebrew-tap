class Ollaya < Formula
  desc "Run open decision models locally"
  homepage "https://github.com/ollaya-dev/ollaya"
  url "https://github.com/ollaya-dev/ollaya/releases/download/v0.9.0/ollaya-darwin-arm64.tar.zst"
  sha256 "9572fc25e59acb58f1ef07be48a0af0804ac8b9b8d0e6b34026c6618d4fa6518"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "zstd" => :build

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :sonoma

    resource "mlx" do
      url "https://github.com/ollaya-dev/ollaya/releases/download/v0.9.0/ollaya-darwin-arm64-mlx.tar.zst"
      sha256 "d251146511d560e146c93f2ee8b3c7fa39aeec90ba150711e12c1587c47ee439"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/ollaya-dev/ollaya/releases/download/v0.9.0/ollaya-linux-amd64.tar.zst"
      sha256 "0c4240ac33667b8316ff70eaf7ac09aafa932c54a58fdb735284f7e93ca7d853"
    end
    on_arm do
      url "https://github.com/ollaya-dev/ollaya/releases/download/v0.9.0/ollaya-linux-arm64.tar.zst"
      sha256 "53f9bcfdb926436331bbc2f7945dbad53ebaf7ddae2fc84eed56850e3cc9b8ce"
    end
  end

  def install
    bin.install "bin/ollaya"
    lib.install "lib/ollaya"
    pkgshare.install "share/ollaya/skills"
    doc.install Dir["share/doc/ollaya/*"]

    if OS.mac?
      resource("mlx").stage do
        (lib/"ollaya").install "lib/ollaya/mlx_metal"
        doc.install "share/doc/ollaya/mlx_metal"
      end
    end
  end

  service do
    run [opt_bin/"ollaya", "serve"]
    keep_alive true
    log_path var/"log/ollaya.log"
    error_log_path var/"log/ollaya.err.log"
  end

  def caveats
    <<~EOS
      Start the Ollaya service:
        brew services start ollaya

      The API listens on http://127.0.0.1:11435 by default.
      Models are stored in ~/.ollaya/models and are not removed by upgrades.
      Stop any CLI-started daemon with `ollaya stop` before starting the service.

      Logs are written to:
        #{var}/log/ollaya.log
        #{var}/log/ollaya.err.log
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ollaya --version 2>&1")
    assert_path_exists lib/"ollaya/llama"
    assert_path_exists lib/"ollaya/mlx_metal/mlx.metallib" if OS.mac?
    assert_path_exists pkgshare/"skills/ollaya-decisions/SKILL.md"
    assert_match '"type": "cpu"', shell_output("#{bin}/ollaya llama-devices")

    port = free_port
    ENV["OLLAYA_HOST"] = "127.0.0.1:#{port}"
    ENV["OLLAYA_MODELS"] = (testpath/"models").to_s
    ENV.delete("OLLAYA_API_KEY")
    pid = fork { exec bin/"ollaya", "serve" }
    begin
      response = shell_output("curl --silent --fail --retry 30 --retry-connrefused --retry-delay 1 " \
                              "--max-time 2 http://127.0.0.1:#{port}/api/version")
      assert_match version.to_s, response
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
