# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Aipr < Formula
  desc "A CLI tool to automate GitHub PR creation/updates using LLMs (like OpenAI) to generate meaningful PR titles and descriptions."
  homepage "https://github.com/tenfyzhong/aipr"
  url "https://github.com/tenfyzhong/aipr/archive/refs/tags/0.1.2.tar.gz"
  sha256 "57c4dc6550ba323da42128cb1ce1e376176f0f9d34dfaf3e605913f987a26ca6"
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
