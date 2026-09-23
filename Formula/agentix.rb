class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.10.tar.gz"
  sha256 "79b9295ef70aefdcb3544c8546aa927c0d7c3e44a75eb3ec659b6263a1d7bef8"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.10"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "8b00fa6fe390565eff35dd2ca0e528d0e57e567e3facd2277fbce72d14831391"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "6c8986499d78ee22f11090704b64fa7fe853b4b09b977a0ad6ca63bb21ea7e0c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "3f57bbb9e9c5d0d60606a9ee14bcd7cb128ee2e8939d033699c0f1990ca1427d"
  end

  depends_on "protobuf" => :build
  depends_on "rust" => :build

  def install
    system "bash", ".github/scripts/set-release-version.sh", version.to_s unless build.head?
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
    assert_equal "https://github.com/tenfyzhong/agentix.git", head&.url
    assert_equal "main", head.specs[:branch]
    assert_path_exists bash_completion/"agentix"
    assert_path_exists zsh_completion/"_agentix"
    assert_path_exists fish_completion/"agentix.fish"
    assert_path_exists pkgshare/"agentix.example.toml"
    assert_match "agentix ", shell_output("#{bin}/agentix --version")
    assert_match version.to_s, shell_output("#{bin}/agentix --version") unless build.head?
  end
end
