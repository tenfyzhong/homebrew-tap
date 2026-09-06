# homebrew-tap

## Agentix

Install [Agentix](https://github.com/tenfyzhong/agentix):

```sh
brew install tenfyzhong/tap/agentix
```

The formula also installs shell completions for Bash, Zsh, and Fish.

## Taskcli

Install [taskcli](https://github.com/tenfyzhong/agentix), the standalone agent task manager:

```sh
brew install tenfyzhong/tap/taskcli
```

Prebuilt bottles are available for Apple Silicon on macOS Sequoia and later.
Other platforms build from source and require Rust at build time.

The formula also installs shell completions for Bash, Zsh, and Fish, and an example
configuration at `$(brew --prefix taskcli)/share/taskcli/taskcli.example.toml`.
Run `taskcli init --help` to configure task storage and document output.
