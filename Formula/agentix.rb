class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.3.1.tar.gz"
  sha256 "4387e4ae3f447dd80d6387c55eb692a3b20054c1250588ec48d4a4f43cb6c1da"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.3.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "5ad3491e5b1f34018e5317d9ac7e9c4a960651c98ea0a560315dea0cb41e2ec5"
    sha256 cellar: :any,                 arm64_linux:   "d5ebe24aea7f3fdcfb889320c421a4a930aa098e26c2d1e12071eb4e95a6ac67"
    sha256 cellar: :any,                 x86_64_linux:  "7d2e12d34c0ffe582a1638c584e1a3a0b52f36b53f15d873bed3ae7d57e56ab2"
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
