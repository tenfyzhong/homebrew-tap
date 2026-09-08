class Taskcli < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.2.4.tar.gz"
  sha256 "f0d976fab3bd1b86f0951f7431caa829c34b730a4bf1b6ce4208aee3520096e5"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.2.4"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "cb0bda316cde14a0367bfe9521300b8e8ba211736bd689d274428ad6873df04c"
  end

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

    (testpath/"documents/.obsidian").mkpath
    system bin/"taskcli", "--config", testpath/"config.toml", "init",
           "--root", testpath/"documents",
           "--database", testpath/"tasks.sqlite3"
    assert_path_exists testpath/"config.toml"
    assert_path_exists testpath/"tasks.sqlite3"
    assert_path_exists testpath/"documents/Dashboard.base"

    output = shell_output("#{bin}/taskcli --config #{testpath}/config.toml --json project list")
    result = JSON.parse(output)
    assert_equal true, result["ok"]
    assert_equal [], result["result"]
  end
end
