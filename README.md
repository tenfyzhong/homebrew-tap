# homebrew-tap

## Agentix

Install [Agentix](https://github.com/tenfyzhong/agentix):

```sh
brew install tenfyzhong/tap/agentix
```

The formula also installs shell completions for Bash, Zsh, and Fish.

## Taskix

Install [taskix](https://github.com/tenfyzhong/agentix), the standalone agent task manager:

```sh
brew install --HEAD tenfyzhong/tap/taskix
```

Until the first Taskix release is published, the formula builds from the
Agentix main branch and requires Rust. Merge the Taskix source rename before
this formula. The Agentix release workflow will add the stable source and an
Apple Silicon bottle; after that, omit `--HEAD` to install the release.

The formula is maintained exclusively in this tap at `Formula/taskix.rb`.
Agentix release automation updates it here and creates formula update pull requests.

The formula also installs shell completions for Bash, Zsh, and Fish, and an example
configuration at `$(brew --prefix taskix)/share/taskix/taskix.example.toml`.
Run `taskix init --help` to configure task storage and document output.
