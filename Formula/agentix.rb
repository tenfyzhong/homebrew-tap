class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.4.tar.gz"
  sha256 "2bcf910ddbe12b27d948883a884af792c10cc7b75db6cadf02b3f05f6dfe8e78"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.4"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ad45499a2b033e5f336e86abd3dee360ba1531743188490b9e782928561959c4"
    sha256 cellar: :any,                 arm64_linux:   "9c377ef865371005b4303197471061794c82ec36a142f9076ff7136aa1d68941"
    sha256 cellar: :any,                 x86_64_linux:  "a6d6d853d6cd73de323068cf488805e358f5fd3f65d49aa82f77db9d79618d50"
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
