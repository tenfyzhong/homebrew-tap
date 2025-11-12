# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://docs.brew.sh/rubydoc/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class RimeDictManager < Formula
  desc "一个用于管理 [Rime](https://rime.im/) 用户词典的命令行工具."
  homepage "https://github.com/tenfyzhong/rime-dict-manager"
  url "https://github.com/tenfyzhong/rime-dict-manager/archive/refs/tags/0.1.1.tar.gz"
  sha256 "d185831827d5a1c41f90defb6334df2c98b6d6bbff3515163fb2dad9924c7be8"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", "-ldflags", "-X 'github.com/tenfyzhong/rime-dict-manager/config.Version=#{version}'", "-o", bin/"rime-dict-manager"
  end

  test do
    system "go", "test", "./..."
  end
end
