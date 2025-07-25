# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class LlmCommitMsg < Formula
  desc "A git hook that uses a large language model to automatically generate a commit message from the staged changes. "
  homepage "https://github.com/tenfyzhong/llm-commit-msg"
  url "https://github.com/tenfyzhong/llm-commit-msg/archive/refs/tags/0.1.0.tar.gz"
  sha256 "3535a32675b474f3bae7c807eb48c540ebdc396c0ffee32429f8b39289f47a34"
  license "MIT"

  depends_on "git"
  depends_on "llm"

  def install
    bin.install "llm-commit-msg"
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
      # Setup git hook(example)
      ## Global Setup
        1. Create global hooks directory
           mkdir -p ~/.git-hooks
        2. Configure Git to use this directory
           git config --global core.hooksPath .git-hooks
        3. Link the hook script:
           ln -s "$(which llm-commit-msg)" ~/.git-hooks/prepare-commit-msg
      ## Per-Project Setup
        1. Navigate into your project's hooks directory
           cd /path/to/your/repo/.git/hooks
        2. Link the hook script:
           ln -s "$(which llm-commit-msg)" ./prepare-commit-msg
    EOS
  end

  test do
  end
end
