# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.3.0.tar.gz"
  sha256 "6cdad285121943e2b6ac3504102c81a9e77e391f678e43d8af55651ae50d2bd8"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.3.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "950a1e65d79c3332f15f3dc69974ac27af1cd4a9b9b7b3f534a5962848286e00"
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
