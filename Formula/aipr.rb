# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Aipr < Formula
  desc "A CLI tool to automate GitHub PR creation/updates using LLMs (like OpenAI) to generate meaningful PR titles and descriptions."
  homepage "https://github.com/tenfyzhong/aipr"
  url "https://github.com/tenfyzhong/aipr/archive/refs/tags/0.1.0.tar.gz"
  sha256 "3f247b1211edf5937fa3ea885943c6124fc85d36098378f5aafe567ffd538031"
  license "MIT"

  depends_on "git"
  depends_on "gh"
  depends_on "jq"
  depends_on "llm"

  def install
    bin.install "aipr"

    bash_completion.install "completions/aipr.bash" => "aipr"
    zsh_completion.install "completions/_aipr" => "_aipr"
    fish_completion.install "completions/aipr.fish" => "aipr.fish"

    pkgshare.install "prompts"
  end

  test do
  end
end
