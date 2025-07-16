# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Aipr < Formula
  desc "A CLI tool to automate GitHub PR creation/updates using LLMs (like OpenAI) to generate meaningful PR titles and descriptions."
  homepage "https://github.com/tenfyzhong/aipr"
  url "https://github.com/tenfyzhong/aipr/archive/refs/tags/0.1.5.tar.gz"
  sha256 "d6bfe8e169e5eba3ac003633412ef2e687110e4c4fb4753bb013c89489475876"
  license "MIT"

  depends_on "git"
  depends_on "gh"
  depends_on "gojq"
  depends_on "llm"

  def install
    bin.install "aipr"

    bash_completion.install "completions/aipr.bash" => "aipr"
    zsh_completion.install "completions/_aipr" => "_aipr"
    fish_completion.install "completions/aipr.fish" => "aipr.fish"

    pkgshare.install "prompts"
  end

  def caveats
    <<~EOS
      After installation, you need to:
      1. Configure GitHub CLI (gh) if not already done:
         gh auth login

      2. Set up LLM credentials (e.g., for OpenAI):
         llm keys set openai

      3. The tool's prompt templates are installed to:
         #{pkgshare}/prompts
    EOS
  end

  test do
  end
end
