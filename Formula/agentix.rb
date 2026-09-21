class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.9.tar.gz"
  sha256 "ae35222f79c022d6f97da3eef61a2d997a1974514b4f24b107d0d2fef1fc017f"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.9"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d3e026e9585bc53a075ac0c76e77e0d9408265cd8ebe847012014493dbc5e209"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "770586891cb23b411a4184c9d8ba9ef4dc6912cfe9a59b31cb0ae7d5352e80ab"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "08171dee4fe7357d4e31e04f8750c7bc9bbfb3af7f77f5960ee7c0d0987318cc"
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
