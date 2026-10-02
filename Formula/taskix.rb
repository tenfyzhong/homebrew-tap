# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
local_library = File.expand_path("../lib/agentix_local_build.rb", __dir__)
local_library = File.expand_path("../share/taskix/agentix_local_build.rb", __dir__) unless File.file?(local_library)
require local_library

class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.4.12.tar.gz"
  sha256 "2d84b365ce43d07722d5a72f55e87e082b9903475d9c4e8a8ee4322b1feb1be9"
  AgentixLocalBuild.configure(self, "taskix", __dir__)
  license "MIT"
  unless AgentixLocalBuild.active?("taskix", __dir__)
    head "https://github.com/tenfyzhong/agentix.git", branch: "main"
  end

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.4.12"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "63778523c80d5d5b385aedb5d95deb5ffb02ea1d345392dd364c5a019413f839"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "a2e79e459a48617709196ee662908580b8df8a3e2816c7e9bd28a305ad1df19b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "785b4f1553489a4d681df340ff5fa041073d9881e3ed1a949acf2fcef3637e5a"
  end

  unless AgentixLocalBuild.active?("taskix", __dir__)
    depends_on "rust" => :build
  end

  def install
    local_build = AgentixLocalBuild.active?("taskix", __dir__)
    if local_build
      bin.install "bin/taskix"
    else
      system "bash", ".github/scripts/set-release-version.sh", version.to_s unless build.head?
      system "cargo", "install", *std_cargo_args(path: "crates/taskix")
    end
    AgentixLocalBuild.install(self, "taskix", __dir__)
    pkgshare.install "config/taskix.example.toml"

    bash_completion.install "completions/taskix.bash" => "taskix"
    zsh_completion.install "completions/_taskix"
    fish_completion.install "completions/taskix.fish"
  end

  service do
    run [opt_bin/"taskix", "memory", "serve"]
    keep_alive true
    stop_timeout 30
    log_path var/"log/taskix.log"
    error_log_path var/"log/taskix.err.log"
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

      With a memory-capable build, configure [memory] and set enabled = true,
      then start the memory service:
        brew services start tenfyzhong/tap/taskix

      On macOS/Linux, Taskix loads exported variables from your login shell.
      If your login shell is fish, put service variables outside any
      `status is-interactive` guard, then restart after changing them.
      Release 0.4.12 does not include memory; use --HEAD until a newer release.
    EOS
  end

  test do
    assert_equal [opt_bin/"taskix", "memory", "serve"].map(&:to_s), service.command

    assert_match "cp -n #{pkgshare}/taskix.example.toml ~/.config/taskix/config.toml", caveats
    assert_match "Then edit ~/.config/taskix/config.toml", caveats
    assert_match(/taskix obsidian setup\s+taskix sync/, caveats)
    assert_match "brew services start tenfyzhong/tap/taskix", caveats

    assert_path_exists bash_completion/"taskix"
    assert_path_exists zsh_completion/"_taskix"
    assert_path_exists fish_completion/"taskix.fish"
    assert_path_exists pkgshare/"taskix.example.toml"
    assert_match "taskix ", shell_output("#{bin}/taskix --version")
    local_build = AgentixLocalBuild.active?("taskix", __dir__)
    if !build.head? && !local_build
      assert_match version.to_s, shell_output("#{bin}/taskix --version")
    end

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
