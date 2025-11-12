# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://docs.brew.sh/rubydoc/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class RimeDictManager < Formula
  desc "一个用于管理 [Rime](https://rime.im/) 用户词典的命令行工具."
  homepage "https://github.com/tenfyzhong/rime-dict-manager"
  url "https://github.com/tenfyzhong/rime-dict-manager/archive/refs/tags/0.1.0.tar.gz"
  sha256 "abe7bcb941f34b4515b6767952a3dd781cdd3cc5ffaf8cdce874973c2c7dd72d"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", "-ldflags", "-X 'github.com/tenfyzhong/rime-dict-manager/config.Version=#{version}'", "-o", bin/"rime-dict-manager"
  end

  test do
    system "go", "test", "./..."
  end
end
