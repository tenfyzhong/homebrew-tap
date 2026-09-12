# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.2.tar.gz"
  sha256 "b3c0437bb4e7d4d15bd31b25c1215021d55e5e10db061f5622f3efec691bb6e8"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.2"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ee2841193d1861ca5e4fd6795379c77c57399a43758f8106c8fe38e992e314e7"
    sha256 cellar: :any,                 arm64_linux:   "4c5ab4f9948558fe357394d2034fa1bfc08ad2757ca57e0f7e3a89a5f10a81b3"
    sha256 cellar: :any,                 x86_64_linux:  "091ea921c984e16b299666f5951c97cab10b95b909541fa2a4499f1ee90f7aaa"
  end

  depends_on "rust" => :build

  def install
    system "bash", ".github/scripts/set-release-version.sh", version.to_s unless build.head?
    system "cargo", "install", *std_cargo_args(path: "crates/taskix")
    pkgshare.install "config/taskix.example.toml"

    bash_completion.install "completions/taskix.bash" => "taskix"
    zsh_completion.install "completions/_taskix"
    fish_completion.install "completions/taskix.fish"
  end

  test do
    assert_path_exists bash_completion/"taskix"
    assert_path_exists zsh_completion/"_taskix"
    assert_path_exists fish_completion/"taskix.fish"
    assert_path_exists pkgshare/"taskix.example.toml"
    assert_match "taskix ", shell_output("#{bin}/taskix --version")
    assert_match version.to_s, shell_output("#{bin}/taskix --version") unless build.head?

    (testpath/"documents/.obsidian").mkpath
    system bin/"taskix", "--config", testpath/"config.toml", "init",
           "--root", testpath/"documents",
           "--database", testpath/"tasks.sqlite3"
    assert_path_exists testpath/"config.toml"
    assert_path_exists testpath/"tasks.sqlite3"
    assert_path_exists testpath/"documents/Dashboard.base"
    system bin/"taskix", "obsidian", "setup", "--help"

    output = shell_output("#{bin}/taskix --config #{testpath}/config.toml --json project list")
    result = JSON.parse(output)
    assert_equal true, result["ok"]
    assert_equal [], result["result"]
  end
end
