local_library = File.expand_path("../lib/agentix_local_build.rb", __dir__)
local_library = File.expand_path("../share/agentix/agentix_local_build.rb", __dir__) unless File.file?(local_library)
require local_library

class Agentix < Formula
  desc "Control local coding-agent sessions from IM"
  homepage "https://github.com/tenfyzhong/agentix"
  url "https://github.com/tenfyzhong/agentix/archive/refs/tags/0.6.1.tar.gz"
  sha256 "3768f90f36c67472917347c3edd1382cefdb4d7a6d64e6befb0b24a83a4875f8"
  license "MIT"

  bottle do
    root_url "https://github.com/tenfyzhong/agentix/releases/download/0.6.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "0c69a784d8cb4e0fc9d04a775ef4434491bd6d0ab91d478ec92a6699bc1efa55"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "87420980cd47491df98b829efa8d810c9a4149940691a4cee4ccc5188f8fd5c7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "9291299617495c8fa4dfc3eb2d879c54bf71c3886f70934a7941f851857263cc"
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
