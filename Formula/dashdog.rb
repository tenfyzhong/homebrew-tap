class Dashdog < Formula
  desc "dashdog is a tool to generate docset for [dash](https://kapeli.com/dash)"
  homepage "https://github.com/tenfyzhong/dashdog"
  url "https://github.com/tenfyzhong/dashdog/archive/refs/tags/0.1.0.tar.gz"
  sha256 "4db95630caa0f670acf3778fd40553df4c83217f579869ef1f3db56b07f1ea66"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", "-ldflags", "-X 'github.com/tenfyzhong/dashdog/cmd/dashdog/config.Version=#{version}'", "-o", bin/"dashdog", "./cmd/dashdog"
    bash_completion.install "cmd/dashdog/completions/dashdog.bash" => "dashdog"
    zsh_completion.install "cmd/dashdog/completions/_dashdog" => "dashdog"
    fish_completion.install "cmd/dashdog/completions/dashdog.fish" => "dashdog.fish"
    bash_completion.install "cmd/dashdog/completions/dashdog-go.bash" => "dashdog-go"
    zsh_completion.install "cmd/dashdog/completions/_dashdog-go" => "dashdog-go"
    fish_completion.install "cmd/dashdog/completions/dashdog-go.fish" => "dashdog-go.fish"
    pkgshare.install "conf"
  end

  test do
    output = shell_outpu("#{bin}/dashdog -h")
    assert_equal "NAME:
   dashdog - a tool to generate docset from html for dash

USAGE:
   dashdog -c|--config <file> [--log off] [config options]

VERSION:
   dev

AUTHOR:
   tenfyzhong

GLOBAL OPTIONS:
   --config file, -c file  the config file to load
   --help, -h              show help (default: false)
   --log level             log level, the log will print to stdout, available value:[debug,info,warn,error,off] (default: \"off\")
   --version, -v           print the version (default: false)

   config

   --bundle-pattern pattern          a pattern to match the path of the sub module name, the group captured can be use in the --bundle-replace flag, it will overwrite the value of `sub_path_bundle_name->pattern` item in the config
   --bundle-replace replace-pattern  a replace-pattern to replace the path which matched by --bundle-pattern flag, it will overwrite the value of `sub_pattern_bundle_name->replace` item in the config
   --cfbundle bundle                 the bundle of the root page, it will overwrite the value of `plist->cfbndle_name` item in the config
   --depth depth                     the max depth of sub page to generate, at least 1, it will overwrite the value of `depth` item in the config (default: 1)
   --name name                       the name of the docset, it will overwrite the value of `name` item in the config file
   --path path                       the path to generate docset, it will overwrite the value of `path` item in the config file (default: \"$HOME/dashdog-doc/\")
   --path-regex pattern              the sub path which match the pattern will be able to generate, it will overwrite the value of `sub_path_regex` item in the config
   --url url                         the source url of the docset, it will overwrite the value of `url` item in the config


COPYRIGHT:
   Copyright (c) 2024 tenfy
", output
  end
end
