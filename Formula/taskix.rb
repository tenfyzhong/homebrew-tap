# frozen_string_literal: true

# Standalone Taskix CLI and bundled Obsidian sync integration.
local_library = File.expand_path("../lib/agentix_local_build.rb", __dir__)
local_library = File.expand_path("../share/taskix/agentix_local_build.rb", __dir__) unless File.file?(local_library)
require local_library

class Taskix < Formula
  desc "Coordinate agent tasks with leases, plans, and Markdown boards"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.5.1.tar.gz"
  sha256 "77fec12b7fb663de8863290558481aff0fcd277d04bfe040ff43f7c52d8e0e7e"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.5.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "12b6ad354bf4809ccaa1b655fa562b2fb6ac10cd65fc20bbf67429d75ab5cef7"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "52c94e4d928c7e984e8492d57e8cfc9e32ae19f2bc721b4613262b0b7c93ca73"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c0bdff2cebf4c826794963c189fe435c16a852b1ad71b6141164bc0b1d16cbdd"
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

      Configure [memory] and export TASKIX_MEMORY_ENABLED=true in your login shell,
      then start the Taskix service:
        brew services start tenfyzhong/tap/taskix

      On macOS/Linux, Taskix loads exported variables from your login shell.
      If your login shell is fish, put service variables outside any
      `status is-interactive` guard, then restart after changing them.
      With a build containing the top-level service commands, reload config with:
        taskix reload
      Release 0.5.0 uses taskix memory serve and taskix memory reload instead.
      Use a current HEAD or local build for taskix serve and taskix reload.
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
