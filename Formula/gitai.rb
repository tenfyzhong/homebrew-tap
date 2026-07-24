class Gitai < Formula
  desc "AI-assisted Git commit messages, pull requests, and tags"
  homepage "https://github.com/tenfyzhong/gitai"
  url "https://github.com/tenfyzhong/gitai/archive/refs/tags/1.0.1.tar.gz"
  sha256 "0892c26cac95af1ffc3c57b2389a73cc607b1fa422ce8db3687c13ad9a98581c"
  license "MIT"

  depends_on "gh"
  depends_on "git"
  depends_on "jq"

  def install
    bin.install "aipr"
    bin.install "aitag"
    bin.install "ai-commit-msg"
    bin.install "gitai-agent"
    bin.install "gitai-common.sh"

    bash_completion.install "completions/aipr.bash" => "aipr"
    zsh_completion.install "completions/_aipr" => "_aipr"
    fish_completion.install "completions/aipr.fish" => "aipr.fish"
    bash_completion.install "completions/aitag.bash" => "aitag"
    zsh_completion.install "completions/_aitag" => "_aitag"
    fish_completion.install "completions/aitag.fish" => "aitag.fish"

    pkgshare.install "prompts"
  end

  def caveats
    <<~EOS
      After installation, you need to:
      # Setup an AI agent
        1. Install and configure one supported agent: Pi, Oh My Pi, Codex,
           or Claude Code. Set GITAI_AGENT to select one explicitly.

        2. The prompt templates are installed to:
           #{pkgshare}/prompts
      # Setup gh
        1. Configure GitHub CLI (gh) if not already done:
           gh auth login
      # Setup git prepare-commit-msg hook
      ## Global Setup
        1. Create global hooks directory
           mkdir -p ~/.git-hooks
        2. Configure Git to use this directory
           git config --global core.hooksPath .git-hooks
        3. Link the hook script:
           ln -s "$(which ai-commit-msg)" ~/.git-hooks/prepare-commit-msg
      ## Per-Project Setup
        1. Navigate into your project's hooks directory
           cd /path/to/your/repo/.git/hooks
        2. Link the hook script:
           ln -s "$(which ai-commit-msg)" ./prepare-commit-msg
    EOS
  end

  test do
    %w[ai-commit-msg aipr aitag gitai-agent gitai-common.sh].each do |file|
      assert_path_exists bin/file
    end
    assert_match "Usage: gitai-agent", shell_output("#{bin}/gitai-agent 2>&1", 2)
  end
end
