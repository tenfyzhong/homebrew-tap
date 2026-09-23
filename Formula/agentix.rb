class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.11.tar.gz"
  sha256 "0582ce31d1e22dcf4ad0d8cf1f910849867de9877ad44463be15468c6e6348ea"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.11"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "7469f46e0015bba2c1160b8724784e026e4b8a6a59c5cb1f1ccc0570317e78dd"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "e1af8e1449858c198c10015f493bb91a57b9186b5e1a968857cfd046d8a333d8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "82669d985c19dc9e6afb69bd7fed538097f5b008d08357496c4f9c3620429fa8"
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
    # Allow Agentix to drain work and reap its owned Codex process group.
    stop_timeout 30
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
