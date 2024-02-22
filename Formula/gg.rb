class Gg < Formula
  desc "Golang version manager"
  homepage "https://github.com/tenfyzhong/gg"
  url "https://github.com/tenfyzhong/gg/archive/refs/tags/1.1.0.tar.gz"
  sha256 "d4b771afa2bc7e78ea767fae8623cd858a74a9d01c4d3d0b0106ec6e6c041129"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "gg"
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
  use          print the specified version environment
", output
  end
end
