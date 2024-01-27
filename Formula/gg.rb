# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Gg < Formula
  desc "Golang version manager"
  homepage "https://github.com/tenfyzhong/gg"
  url "https://github.com/tenfyzhong/gg/archive/refs/tags/1.0.0.tar.gz"
  sha256 "f18f72621080cdf3cda4db5d47ce16bd5d8b94486f9ee0e63eef07db70c5fed4"
  license "MIT"

  depends_on "curl"

  def install
    bin.install 'gg'
    bash_completion.install "gg-completion.bash" => "gg"
    zsh_completion.install "_gg" => "_gg"
  end

  test do
    output = shell_output("#{bin}/gg -h")
    assert_equal "gg: golang version manager
Usage: gg [options] <subcommand> [options] <args>

Options:
  -h/--help         print this help message

Subcommands:
  ls           list local version
  ls-remote    list remote version
  install      install specified version
  remove       remove specified version
  use          print the specified version environment", output
  end
end
