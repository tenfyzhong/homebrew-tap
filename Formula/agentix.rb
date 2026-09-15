class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.7.tar.gz"
  sha256 "5044c1286635890812cfde3fb41eb9cec83c5529ec3f16bd9011a599c9f7886a"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.7"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e9961d9655dfb0bfae26ae73078768da1a5c4f77f9ac7ce37d1addcf322348b3"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "4b6c0daea1d566473f805577add5fe3b4f402ee55b9cce6406c03e901b6dd773"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "29f2a2d41bb53556dcaf8c3315320d6ec3c61716783473d0219534934d09cfd8"
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
