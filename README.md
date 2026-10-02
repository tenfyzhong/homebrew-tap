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

## Installing local Agentix binaries

Build the Agentix checkout first using its normal toolchain:

```sh
cd /absolute/path/to/agentix
make release
```

The Formulae can install those existing binaries directly from any directory:

```sh
env HOMEBREW_AGENTIX_LOCAL_SOURCE=/absolute/path/to/agentix \
  brew reinstall --build-from-source tenfyzhong/tap/agentix tenfyzhong/tap/taskix
```

Select only one Formula if desired. The tap must contain precompiled local
installation support. `--build-from-source` makes Homebrew run the Formula
installation recipe for the local archive; the local recipe copies binaries
and does not invoke Cargo or install Rust/LLVM or Protobuf build dependencies.
Stable/remote HEAD source builds retain their existing build dependencies.
While local mode is active, the Formula exposes only the local artifact spec,
so `reinstall` uses that archive even when a remote HEAD version is installed.

`HOMEBREW_AGENTIX_LOCAL_PROFILE` defaults to `release`. Build with `make`, then
set it to `debug` to install existing debug binaries. The binaries must be
executable and built for the current machine. Their enabled features and Cargo
version come from the earlier build; rebuild explicitly after changing source.
Missing binaries or resources fail before installation with an actionable error.

By default, binaries are read from `target/<profile>/` in the checkout. For a
custom Cargo target directory, set `HOMEBREW_AGENTIX_LOCAL_TARGET_DIR` to that
same directory. Relative paths are resolved against the checkout. Example:

```sh
cd /absolute/path/to/agentix
make release CARGO_TARGET_DIR=/absolute/path/to/build

env HOMEBREW_AGENTIX_LOCAL_SOURCE=/absolute/path/to/agentix \
  HOMEBREW_AGENTIX_LOCAL_TARGET_DIR=/absolute/path/to/build \
  brew reinstall --build-from-source tenfyzhong/tap/agentix
```

The helper snapshots each selected binary and its example configuration and
Bash/Zsh/Fish completions into a checksummed archive in Homebrew's cache. Source
files and other build outputs are excluded; configuration and completion edits
are included. Files are copied into the snapshot, including symlink targets,
so installation does not depend on paths outside that archive. Keep the inputs
unchanged while the snapshot is created. The checkout and Formula files stay
untouched.

Each artifact/profile snapshot uses a content-derived
`0.0.0-local.<digest>.<profile>` Cellar version. Installed metadata includes the
helper and snapshot record, so it remains readable after removing the checkout.
Homebrew owns keg replacement, command linking and normal failure recovery.
Services are not restarted automatically.

The Agentix Makefile wraps this operation as `make update VERSION=local`, with
`PROFILE=release|debug`, `FORMULAE=agentix|taskix` and `CARGO_TARGET_DIR` support.
`make switch VERSION=local` selects an already installed local build without
building or installing. To return to an upstream release or remote HEAD, unset
the local variables and run `brew reinstall` or `brew reinstall --HEAD`, or use
the Agentix Makefile's stable/HEAD update and switch targets.

### Local installation tests

```sh
node --test tests/*.test.mjs
AGENTIX_TEST_HOMEBREW=1 node --test tests/local-install.test.mjs
```

The normal suite checks artifact snapshots, content identity, missing inputs,
profile/target selection, dependency declarations, Formula installation and
installed metadata. The opt-in test builds a uniquely named Rust fixture outside
Homebrew, installs release/debug artifacts through the actual Formula recipe
starting from an installed HEAD keg, with its dependency declarations intact,
verifies no build dependencies and byte-for-byte binary reuse, checks
links/resources and loads metadata after
removing the checkout. It removes its fixture kegs and tap afterwards and never
starts Agentix or Taskix services.
