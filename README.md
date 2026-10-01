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

### Development versions

Agentix and Taskix support building the latest `main` branch from source:

```sh
brew install --HEAD tenfyzhong/tap/agentix
brew install --HEAD tenfyzhong/tap/taskix
```

If a stable version is already installed, unlink that formula first, for example:

```sh
brew unlink taskix
brew install --HEAD tenfyzhong/tap/taskix
```

Use the same sequence with `agentix` to switch Agentix. Unlinking preserves the
installed stable version and your configuration.

To keep the stable command linked while compiling HEAD, install with
`--skip-link`, then switch after a successful build:

```sh
brew install --HEAD --skip-link tenfyzhong/tap/taskix
brew unlink taskix
brew link --HEAD taskix
```

`--skip-link` skips links in Homebrew's prefix, but Homebrew can still update the
formula's `opt` link. Services or scripts using that path may pick up HEAD on
their next start.

HEAD builds require Rust;
Agentix also requires Protobuf. Homebrew installs these build dependencies.

To update an installed HEAD build to the latest `main` commit:

```sh
brew upgrade --fetch-HEAD tenfyzhong/tap/agentix tenfyzhong/tap/taskix
```

Include only the formulae you installed as HEAD. If Agentix is running as a
Homebrew service, restart it after switching or upgrading:

```sh
brew services restart tenfyzhong/tap/agentix
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

To build from the Agentix `main` branch instead, follow
[Development versions](#development-versions), including the unlink step if the
stable version is already installed.

#### Memory service

The Taskix service runs `taskix memory serve`. Release 0.4.12 does not include
memory; use a HEAD build until a newer release is available. Configure `[memory]`
in `~/.config/taskix/config.toml`, including `enabled = true` and your model
provider, before starting it:

```sh
brew services start tenfyzhong/tap/taskix
```

The formula starts Taskix directly. On macOS/Linux, memory-capable builds with
login-environment support run the user's account login shell with `-lc`, capture
its exported environment and replace the service process with the same PID.
Failed or timed-out lookups retain the inherited environment. The formula does
not require Fish; if Fish is your login shell, export API keys and proxy variables
with `set -gx` outside `status is-interactive` guards in your Fish configuration.
Variables set only in a terminal session are not loaded by a new service process.
`TASKIX_LOGIN_SHELL` can select a different absolute shell path when supplied to
the service process. This code change must be included in the installed build.

After changing Fish variables or upgrading Taskix, restart and check the service:

```sh
brew services restart tenfyzhong/tap/taskix
taskix memory status
```

Logs are written to `$(brew --prefix)/var/log/taskix.log` and
`$(brew --prefix)/var/log/taskix.err.log`. Stop any separately started
`taskix memory serve` process before switching to the Homebrew service.

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
