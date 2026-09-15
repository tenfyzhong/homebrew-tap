class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.8.tar.gz"
  sha256 "c064e459fa60b48a4283686fa1a1285cbbf8f2902f703abe77fbfbb7693d0807"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.8"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "c50d886fb90d0743550977e6eb19ffb21b29f122652309419900ef2c6364a8cb"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "c99a48ca044283d9c17286eda2a6f428e293cccee534f3112b1374e0f0340b1c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "265b23d6fec318741977961cb6b99524af6b838ab21b9fc1623a3f253a8d6788"
  end

  depends_on "protobuf" => :build
  depends_on "rust" => :build

  def install
    system "bash", ".github/scripts/set-release-version.sh", version.to_s
    system "cargo", "install", *std_cargo_args(path: "crates/agentix")
    pkgshare.install "config/agentix.example.toml"

    bash_completion.install "completions/agentix.bash" => "agentix"
    zsh_completion.install "completions/_agentix"
    fish_completion.install "completions/agentix.fish"
  end

  service do
    run [opt_bin/"agentix", "serve"]
    keep_alive true
    log_path var/"log/agentix.log"
    error_log_path var/"log/agentix.err.log"
  end

  def caveats
    <<~EOS
      Create the default configuration before starting Agentix:
        mkdir -p ~/.config/agentix
        cp #{pkgshare}/agentix.example.toml ~/.config/agentix/config.toml

      Then edit the configuration and start the service:
        brew services start tenfyzhong/tap/agentix
    EOS
  end

  test do
    assert_path_exists bash_completion/"agentix"
    assert_path_exists zsh_completion/"_agentix"
    assert_path_exists fish_completion/"agentix.fish"
    assert_path_exists pkgshare/"agentix.example.toml"
    assert_match version.to_s, shell_output("#{bin}/agentix --version")
  end
end
