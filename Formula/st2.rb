class St2 < Formula
  desc "`st2` generate go/protobuf/thrift code from json/protobuf/thrift/go/csv code"
  homepage "https://github.com/tenfyzhong/st2"
  url "https://github.com/tenfyzhong/st2/archive/refs/tags/1.7.0.tar.gz"
  sha256 "4a6b89457fbffa53eb41fa5d5e10f943cd6e36a118bcbec2f9d27b8ea913a667"
  license "MIT"

  depends_on "go" => :build

  on_linux do
    depends_on "libx11"
  end

  def install
    system "go", "build", "-ldflags", "-X 'github.com/tenfyzhong/st2/cmd/st2/config.Version=#{version}'", "-o", bin/"st2", "./cmd/st2"
    bash_completion.install "cmd/st2/autocomplete/bash_autocomplete" => "st2"
    zsh_completion.install "cmd/st2/autocomplete/zsh_autocomplete" => "st2"
    fish_completion.install "cmd/st2/completions/st2.fish" => "st2.fish"
  end

  test do
    status_output = shell_output("echo '{\"hello\": \"world\"}' | #{bin}/st2 -s json -d go")
    assert_equal "type Root struct {
\tHello string `json:\"hello,omitempty\"`
}

", status_output
  end
end
