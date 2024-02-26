class Gg < Formula
  desc "Golang version manager"
  homepage "https://github.com/tenfyzhong/gg"
  url "https://github.com/tenfyzhong/gg/archive/refs/tags/1.2.3.tar.gz"
  sha256 "c61bd3c41d2d0095ba5b79a1069a9f581816875bd0743d6150643bf7fe134cd5"
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
