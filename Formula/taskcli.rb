class Taskcli < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.2.1.tar.gz"
  sha256 "ad1a188e1d61c9110f13940adbd8021c504f4d57d6c0d6e5157b16ea29fd8cb5"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "bash", ".github/scripts/set-release-version.sh", version.to_s
    system "cargo", "install", *std_cargo_args(path: "crates/taskcli")
    pkgshare.install "config/taskcli.example.toml"

    bash_completion.install "completions/taskcli.bash" => "taskcli"
    zsh_completion.install "completions/_taskcli"
    fish_completion.install "completions/taskcli.fish"
  end

  test do
    assert_path_exists bash_completion/"taskcli"
    assert_path_exists zsh_completion/"_taskcli"
    assert_path_exists fish_completion/"taskcli.fish"
    assert_path_exists pkgshare/"taskcli.example.toml"
    assert_match version.to_s, shell_output("#{bin}/taskcli --version")

    (testpath/"documents").mkpath
    system bin/"taskcli", "--config", testpath/"config.toml", "init",
           "--root", testpath/"documents",
           "--database", testpath/"tasks.sqlite3"
    assert_path_exists testpath/"config.toml"
    assert_path_exists testpath/"tasks.sqlite3"

    output = shell_output("#{bin}/taskcli --config #{testpath}/config.toml --json project list")
    result = JSON.parse(output)
    assert_equal true, result["ok"]
    assert_equal [], result["result"]
  end
end
