# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Gitai < Formula
  desc "`gitai` is a set of command-line tools that use AI to help you with your Git workflow. It can help you write commit messages, create pull requests, and generate tags."
  homepage "https://github.com/tenfyzhong/gitai"
  url "https://github.com/tenfyzhong/gitai/archive/refs/tags/0.2.1.tar.gz"
  sha256 "af132004c9f0437c5ff83969382825b3e45f54a0f580651f97a86cc5dfe34ff8"
  license "MIT"

  depends_on "git"
  depends_on "gh"
  depends_on "gojq"
  depends_on "llm"

  def install
    bin.install "aipr"
    bin.install "aitag"
    bin.install "ai-commit-msg"

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
      # Setup llm
        1. Setup LLM credentials (e.g., for OpenAI):
           llm keys set openai

        2. The tool's prompt templates are installed to:
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
  end
end
