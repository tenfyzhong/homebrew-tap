local_library = File.expand_path("../lib/agentix_local_build.rb", __dir__)
local_library = File.expand_path("../share/agentix/agentix_local_build.rb", __dir__) unless File.file?(local_library)
require local_library

class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.7.2.tar.gz"
  sha256 "6875fd6cca4c2b8966b8c2d8bfe2ea05ce0a5cd90ced7516fa29c8ecb5b14e17"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.7.2"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "04837a3865db2058d943a9e88ccf027cfa2d9f90499e0adfd7c85cc99ea47959"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "0d8bff4de7fcf366fdfb32e5feb9a21db0ca868c6ccc047bb95c9b66f463db26"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "94ad29ed35de82ee0c909ea4485257de327347d981dbec78774732501426f299"
  end

  AgentixLocalBuild.configure(self, "agentix", __dir__)
  unless AgentixLocalBuild.active?("agentix", __dir__)
    head "https://github.com/tenfyzhong/agentix.git", branch: "main"
  end

  unless AgentixLocalBuild.active?("agentix", __dir__)
    depends_on "protobuf" => :build
    depends_on "rust" => :build
  end

  def install
    local_build = AgentixLocalBuild.active?("agentix", __dir__)
    if local_build
      bin.install "bin/agentix"
    else
      system "bash", ".github/scripts/set-release-version.sh", version.to_s unless build.head?
      system "cargo", "install", *std_cargo_args(path: "crates/agentix")
    end
    AgentixLocalBuild.install(self, "agentix", __dir__)
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
    local_build = AgentixLocalBuild.active?("agentix", __dir__)
    if local_build
      assert_nil head
    else
      assert_equal "https://github.com/tenfyzhong/agentix.git", head&.url
      assert_equal "main", head.specs[:branch]
    end
    assert_path_exists bash_completion/"agentix"
    assert_path_exists zsh_completion/"_agentix"
    assert_path_exists fish_completion/"agentix.fish"
    assert_path_exists pkgshare/"agentix.example.toml"
    assert_match "agentix ", shell_output("#{bin}/agentix --version")
    if !build.head? && !local_build
      assert_match version.to_s, shell_output("#{bin}/agentix --version")
    end
  end
end
