# homebrew-tap

Homebrew formulae for command-line tools by [tenfyzhong](https://github.com/tenfyzhong).

## Installation

With Homebrew installed, install a tool directly using its fully qualified name:

```sh
brew install tenfyzhong/tap/agentix
```

Replace `agentix` with any formula from the table below. You can also add the tap
first:

```sh
brew tap tenfyzhong/tap
brew install tenfyzhong/tap/taskix
```

## Available tools

| Formula | Description | Project |
| --- | --- | --- |
| [`agentix`](Formula/agentix.rb) | Control local coding-agent sessions from IM. | [Agentix](https://github.com/tenfyzhong/agentix) |
| [`dashdog`](Formula/dashdog.rb) | Generate docsets for Dash. | [dashdog](https://github.com/tenfyzhong/dashdog) |
| [`gg`](Formula/gg.rb) | Manage Go versions. | [gg](https://github.com/tenfyzhong/gg) |
| [`gitai`](Formula/gitai.rb) | Generate Git commit messages, pull requests, and tags with AI assistance. | [gitai](https://github.com/tenfyzhong/gitai) |
| [`modeltap`](Formula/modeltap.rb) | Monitor AI traffic through a MITM proxy with configurable egress proxies. | [ModelTap](https://github.com/tenfyzhong/modeltap) |
| [`rime-dict-manager`](Formula/rime-dict-manager.rb) | Manage Rime user dictionaries. | [rime-dict-manager](https://github.com/tenfyzhong/rime-dict-manager) |
| [`st2`](Formula/st2.rb) | Generate Go, Protobuf, and Thrift code from JSON, Protobuf, Thrift, Go, or CSV. | [st2](https://github.com/tenfyzhong/st2) |
| [`taskix`](Formula/taskix.rb) | Coordinate agent tasks with leases, plans, and Markdown boards. | [Taskix (Agentix repository)](https://github.com/tenfyzhong/agentix) |

## Setup

### Agentix

The formula installs shell completions for Bash, Zsh, and Fish, plus an example
configuration. For a first-time setup, copy the example:

```sh
mkdir -p ~/.config/agentix
cp -n "$(brew --prefix agentix)/share/agentix/agentix.example.toml" ~/.config/agentix/config.toml
```

Edit `~/.config/agentix/config.toml` for your environment, then start the service:

```sh
brew services start tenfyzhong/tap/agentix
```

### Taskix

Install the stable release:

```sh
brew install tenfyzhong/tap/taskix
```

The formula installs shell completions for Bash, Zsh, and Fish, and an example
configuration at `$(brew --prefix taskix)/share/taskix/taskix.example.toml`.
To see the options for configuring task storage and document output, run:

```sh
taskix init --help
```

To build the development version from the Agentix `main` branch instead, use
`brew install --HEAD tenfyzhong/tap/taskix`. This builds from source with Rust as
a build dependency.

### Other tools

Check a formula's dependencies and post-installation instructions with
`brew info`, especially for tools that require configuration such as Gitai and
ModelTap:

```sh
brew info tenfyzhong/tap/gitai
brew info tenfyzhong/tap/modeltap
```

Follow the project links above for detailed usage and configuration.

## Upgrading

Update Homebrew's formulae, then upgrade the tools you use:

```sh
brew update
brew upgrade tenfyzhong/tap/agentix tenfyzhong/tap/taskix
```

Replace the formula names with those you have installed.
