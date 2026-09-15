# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.8.tar.gz"
  sha256 "c064e459fa60b48a4283686fa1a1285cbbf8f2902f703abe77fbfbb7693d0807"
  license "MIT"
  head "https://github.com/tenfyzhong/agentix.git", branch: "main"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.8"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "448fe8980b24a65ffff626726acac3c931c89a5037ca3fded5bcbc30f4049bb0"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "cc93f88ca71eb610e19895784adb55c036c067efdef6e030e7a01d4a2914de41"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "071623ef50919fca542071f32b2b4202418bf3c3a78c6a8dd4a451498f434db2"
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

  def caveats
    <<~EOS
      Before using Taskix, copy the example configuration if you do not have one:
        mkdir -p ~/.config/taskix
        cp -n #{pkgshare}/taskix.example.toml ~/.config/taskix/config.toml

      Then edit ~/.config/taskix/config.toml for your Obsidian vault.
      When upgrading, keep your existing configuration and review the example
      for new settings.

      After configuring Taskix, run these commands after installation or upgrade:
        taskix obsidian setup
        taskix sync
    EOS
  end

  test do
    assert_match "cp -n #{pkgshare}/taskix.example.toml ~/.config/taskix/config.toml", caveats
    assert_match "Then edit ~/.config/taskix/config.toml", caveats
    assert_match(/taskix obsidian setup\s+taskix sync/, caveats)

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
