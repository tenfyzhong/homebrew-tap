# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Aitag < Formula
  desc "Automatically generate meaningful Git tag messages using LLM."
  homepage "https://github.com/tenfyzhong/aitag"
  url "https://github.com/tenfyzhong/aitag/archive/refs/tags/0.1.2.tar.gz"
  sha256 "8a2e39f7190c2b47a782856baf9a20ada7fde253bf55b7e48eb6738df2df6ac9"
  license "MIT"

  depends_on "git"
  depends_on "llm"

  def install
    bin.install "aitag"

    bash_completion.install "completions/aitag.bash" => "aitag"
    zsh_completion.install "completions/_aitag" => "_aitag"
    fish_completion.install "completions/aitag.fish" => "aitag.fish"

    pkgshare.install "prompts"
  end

  def caveats
    <<~EOS
      After installation, you need to:
      1. Set up LLM credentials (e.g., for OpenAI):
         llm keys set openai

      2. The tool's prompt templates are installed to:
         #{pkgshare}/prompts
    EOS
  end

  test do
  end
end
