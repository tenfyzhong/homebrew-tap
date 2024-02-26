class Gg < Formula
  desc "Golang version manager"
  homepage "https://github.com/tenfyzhong/gg"
  url "https://github.com/tenfyzhong/gg/archive/refs/tags/1.2.2.tar.gz"
  sha256 "b9abd20e44c67e1fb1fc0ed73745da6da3f60ca44db2a75f3102a6efae92ebf6"
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
