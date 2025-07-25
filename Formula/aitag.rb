# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Aitag < Formula
  desc "Automatically generate meaningful Git tag messages using LLM."
  homepage "https://github.com/tenfyzhong/aitag"
  url "https://github.com/tenfyzhong/aitag/archive/refs/tags/0.1.3.tar.gz"
  sha256 "6378814fb16f87277c59a34e77dd6144276c1e5b887e8374478d847afab508ff"
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
