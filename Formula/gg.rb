class Gg < Formula
  desc "Golang version manager"
  homepage "https://github.com/tenfyzhong/gg"
  url "https://github.com/tenfyzhong/gg/archive/refs/tags/1.2.1.tar.gz"
  sha256 "b6764fff23587a40d755e24f47a6c010854ad6f8e6229248c3635cb3248ca7ee"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "gg"
    bin.install "ggenv"
    bash_completion.install "gg-completion.bash" => "gg"
    bash_completion.install "ggenv-completion.bash" => "ggenv"
    zsh_completion.install "_gg" => "_gg"
    zsh_completion.install "_ggenv" => "_ggenv"
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
  use          print the specified version environment
", output
  end
end
