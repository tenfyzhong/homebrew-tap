class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.0.tar.gz"
  sha256 "de9c85652679d5b4aa354c5fd7e07a6d455457a3205bc8cba952413226d85037"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "66d3b3f3709d0fa0ea02bacf207ab1b6e9b43e8d0f63ff1ede43c2419810223b"
    sha256 cellar: :any,                 arm64_linux:   "93b9fc46f17d6fe31896a1e2337d2af0f546174965b49bc11084587ad5b662ed"
    sha256 cellar: :any,                 x86_64_linux:  "8ce1f1ae324e3e6b6a4d3ba213b28871ff8c2f7902eb22a6c7b7b34ce8636cd6"
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
