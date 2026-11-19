# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
local_library = File.expand_path("../lib/agentix_local_build.rb", __dir__)
local_library = File.expand_path("../share/taskix/agentix_local_build.rb", __dir__) unless File.file?(local_library)
require local_library

class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.8.3.tar.gz"
  sha256 "0de9d5eb54a3e6be10e333364c5cca4e2d561339e534f0fe2d3759a22a12f2f3"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.8.3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "36efafa8b7890c3ba167551a803e4f613b69d6e5b9d0aae8dec8c879717a76f3"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "dde42722c20c6d54796fcffbaded2df19ab8e59ba6833c74b2febfb7a297a534"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b49e16146f68053ab1908cf06036814e6e3e9a81fe12321bff1941a447ea178d"
  end

  AgentixLocalBuild.configure(self, "taskix", __dir__)
  unless AgentixLocalBuild.active?("taskix", __dir__)
    head "https://github.com/tenfyzhong/agentix.git", branch: "main"
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

  def legacy_service?
    !version.head? && !version.to_s.start_with?("0.0.0-local.") && version <= Version.new("0.5.0")
  end

  service do
    if f.legacy_service?
      run [opt_bin/"taskix", "memory", "serve"]
    else
      run [opt_bin/"taskix", "serve"]
    end
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

      Configure [memory] in config.toml. Builds containing Agentix PR #200 load
      taskix.env beside config.toml; put TASKIX_MEMORY_ENABLED=true and provider
      credentials there. Inherited variables override file defaults.
      This is not available in stable 0.7.3. See the tap README for migration.
      Older builds require exported login-shell variables; for fish use set -Ux.
      Start the Taskix service:
        brew services start tenfyzhong/tap/taskix

      Restart the service and resident plugins after editing env files or shell
      variables. For TOML changes affecting future service work, use:
        taskix reload
      Check the service with taskix status.
      Legacy release 0.5.0 uses taskix memory serve, reload and status instead.
    EOS
  end

  test do
    service_args = legacy_service? ? %w[memory serve] : %w[serve]
    assert_equal [opt_bin/"taskix", *service_args].map(&:to_s), service.command

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
