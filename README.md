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
| [`ollaya`](Formula/ollaya.rb) | Run open decision models through a local API. | [Ollaya](https://github.com/ollaya-dev/ollaya) |
| [`rime-dict-manager`](Formula/rime-dict-manager.rb) | Manage Rime user dictionaries. | [rime-dict-manager](https://github.com/tenfyzhong/rime-dict-manager) |
| [`st2`](Formula/st2.rb) | Generate Go, Protobuf, and Thrift code from JSON, Protobuf, Thrift, Go, or CSV. | [st2](https://github.com/tenfyzhong/st2) |
| [`taskix`](Formula/taskix.rb) | Coordinate agent tasks with leases, plans, and Markdown boards. | [Taskix (Agentix repository)](https://github.com/tenfyzhong/agentix) |
| [`taskix-backup`](Formula/taskix-backup.rb) | Back up and restore Taskix SQLite databases with rclone. | [Taskix backups](https://github.com/tenfyzhong/agentix/wiki/Backup-and-Recovery) |

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

#### Taskix service

The Taskix service runs `taskix serve` with a current HEAD or local build.
Release 0.5.0 still uses `taskix memory serve`; the formula retains that command
for the stable release. Configure `[memory]` in `~/.config/taskix/config.toml`
with your model provider, and export `TASKIX_MEMORY_ENABLED=true` in your login
shell before starting it:

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

Reload configuration for future service work with `taskix reload` (release
0.5.0: `taskix memory reload`). Invalid configuration leaves the active settings
unchanged. Storage paths and IPC limits require a restart.

After changing Fish variables or upgrading Taskix, restart and check the service:

```sh
brew services restart tenfyzhong/tap/taskix
taskix memory status
```

Logs are written to `$(brew --prefix)/var/log/taskix.log` and
`$(brew --prefix)/var/log/taskix.err.log`. Stop any separately started
`taskix serve` (or legacy `taskix memory serve`) process before switching to the
Homebrew service.

### Taskix backup

Install the backup command independently of Taskix:

```sh
brew install --HEAD tenfyzhong/tap/taskix-backup
taskix-backup --help
```

The initial Formula is HEAD-only. After the first stable backup Formula is
published by the Agentix release workflow, install without `--HEAD`.
Homebrew installs Python and rclone and fixes the command's Python interpreter.
The tool does not require a running Taskix service or Rust. Use your existing
Taskix configuration and configure a named remote with `rclone config`.
Installing or upgrading the Formula does not configure remotes or schedule backups.
See [Backup and recovery](https://github.com/tenfyzhong/agentix/wiki/Backup-and-Recovery)
for manual runs, launchd/cron scheduling, and restore verification.

### Ollaya

Install Ollaya and start its background service:

```sh
brew install tenfyzhong/tap/ollaya
brew services start ollaya
curl http://127.0.0.1:11435/api/version
```

Supported platforms are Apple Silicon with macOS 14 or later, Linux x86_64,
and Linux ARM64. Linux requires glibc 2.38 or newer, a C++ runtime providing
`GLIBCXX_3.4.31`, and GCC's OpenMP runtime (`libgomp.so.1`), as in Ubuntu 24.04+
with `libgomp1` installed. The Formula installs upstream binaries, llama.cpp runtime
libraries, the bundled agent skill, and the MLX Metal library on macOS.
Linux uses the base CPU package; optional CUDA packs are not installed.
Models remain in `~/.ollaya/models` across upgrades. Download a model with
`ollaya pull laya`, then follow the [upstream documentation](https://github.com/ollaya-dev/ollaya).

If the CLI previously started a daemon, run `ollaya stop` before starting the
Homebrew service so that both processes do not compete for port 11435.
Logs are in `$(brew --prefix)/var/log/ollaya.log` and
`$(brew --prefix)/var/log/ollaya.err.log`. After upgrading:

```sh
brew services restart ollaya
```

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

### Updating the Ollaya Formula from n8n

The [Update Ollaya workflow](.github/workflows/update-ollaya.yml) supports
`workflow_dispatch`. Once this workflow is merged into `main`, run it through
GitHub's **Actions → Update Ollaya → Run workflow**, or call GitHub's
[workflow dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
from an n8n HTTP Request node:

- Method: `POST`
- URL: `https://api.github.com/repos/tenfyzhong/homebrew-tap/actions/workflows/update-ollaya.yml/dispatches`
- Authentication: a GitHub credential with repository **Actions: write** permission
- Headers: `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2026-03-10`
- JSON body:

```json
{
  "ref": "main",
  "inputs": {
    "version": ""
  }
}
```

An empty version selects the latest published stable release. To request a
specific stable release, set `version` to `0.9.0` or `v0.9.0`. Prereleases,
drafts, downgrades, missing packages, and checksum mismatches fail without
changing the Formula. The workflow downloads and verifies all three platform
packages and the separate MLX package, then runs the tap unit tests.
Repeated triggers reuse the `automation/update-ollaya` branch and PR; if the
Formula is already current, no new commit or PR is created.

The workflow creates or updates a signed-off version PR targeting `main`.
Merge that PR to publish the new Formula; it does not automatically merge or
upgrade Ollaya on installed machines. Users subsequently run `brew update`,
`brew upgrade ollaya`, and `brew services restart ollaya`.

For the default `GITHUB_TOKEN`, enable **Settings → Actions → General → Workflow
permissions → Allow GitHub Actions to create and approve pull requests**.
GitHub does not trigger PR CI for PRs created with `GITHUB_TOKEN`. To run the
existing macOS/Linux Homebrew CI automatically on version PRs, configure the
repository secret `OLLAYA_UPDATE_TOKEN` with a fine-grained PAT granting this
repository **Contents: write** and **Pull requests: write**. This is separate
from n8n's dispatch credential. See the action's
[token documentation](https://github.com/peter-evans/create-pull-request#token).

## Installing local Agentix binaries

Build the Agentix checkout first using its normal toolchain:

```sh
cd /absolute/path/to/agentix
make release
```

The Formulae can install those existing binaries directly from any directory:

```sh
env HOMEBREW_AGENTIX_LOCAL_SOURCE=/absolute/path/to/agentix \
  brew install --build-from-source --skip-link tenfyzhong/tap/agentix tenfyzhong/tap/taskix
```

Select only one Formula if desired. The tap must contain precompiled local
installation support. `--build-from-source` makes Homebrew run the Formula
installation recipe for the local archive; the local recipe copies binaries
and does not invoke Cargo or install Rust/LLVM or Protobuf build dependencies.
Stable/remote HEAD source builds retain their existing build dependencies.

Then link the exact installed snapshot through Homebrew. Use the same local
source/profile/target settings and selected Formulae in both commands:

```sh
env HOMEBREW_AGENTIX_LOCAL_SOURCE=/absolute/path/to/agentix \
  brew ruby -e '
    require "formulary"
    require "unlink"
    kegs = ARGV.map do |name|
      formula = Formulary.factory(name, :stable)
      abort "Not installed: #{formula.prefix}" unless formula.prefix.directory?
      Keg.new(formula.prefix)
    end
    kegs.each do |keg|
      ref = HOMEBREW_LINKED_KEGS/keg.name
      Homebrew::Unlink.unlink(Keg.new(ref.realpath)) if ref.symlink?
    end
    kegs.each { |keg| keg.lock { keg.link } }
  ' tenfyzhong/tap/agentix tenfyzhong/tap/taskix
```

`--skip-link` separates installation from command linking. It avoids conflicts
when another version remains linked while `opt` points elsewhere. Plain
`brew unlink <formula>` follows `opt` and can miss the actual linked keg; plain
`brew link <formula>` can select a higher stable version instead of local.
The explicit link step validates every selected snapshot before unlinking the
actual linked kegs. Keep binary/resource inputs unchanged between the two steps.
An install failure should stop the flow before linking. Homebrew can still move
`opt` during staging. Existing stable/HEAD kegs are retained; identical artifacts
can be reused without reinstalling.

While local mode is active, the Formula exposes only the local artifact spec,
so local installation uses that archive even when a remote HEAD version is installed.

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
  brew install --build-from-source --skip-link tenfyzhong/tap/agentix
```

The helper snapshots each selected binary and its example configuration and
Bash/Zsh/Fish completions into a checksummed archive in Homebrew's cache. Source
files and other build outputs are excluded; configuration and completion edits
are included. Files are copied into the snapshot, including symlink targets,
so installation does not depend on paths outside that archive. Keep the inputs
unchanged while the snapshot is created. The checkout and Formula files stay
untouched.

Snapshots are written to a temporary tar file and compressed with the platform
`gzip -n`, avoiding Ruby `GzipWriter` buffer errors on large release binaries.
Temporary disk space must accommodate both the tar and its compressed archive.
Changing the compressor can produce a new local version for identical inputs;
repeat updates with the same inputs and compressor retain the same identity.

Each artifact/profile snapshot uses a content-derived
`0.0.0-local.<digest>.<profile>` Cellar version. Installed metadata includes the
helper and snapshot record, so it remains readable after removing the checkout.
Homebrew owns the installed kegs; linking selects the exact installed snapshot.
Services are not restarted automatically.

The Agentix Makefile wraps this operation as `make update VERSION=local`, with
`PROFILE=release|debug`, `FORMULAE=agentix|taskix` and `CARGO_TARGET_DIR` support.
It runs the same install with `--skip-link`, then its exact local switch only
after all selected installations succeed.
`make switch VERSION=local` selects an already installed local build without
building or installing. To return to an upstream release or remote HEAD, unset
the local variables and run `brew reinstall` or `brew reinstall --HEAD`, or use
the Agentix Makefile's stable/HEAD update and switch targets.

### Local installation tests

```sh
node --test tests/*.test.mjs
AGENTIX_TEST_HOMEBREW=1 node --test --test-name-pattern=homebrew_formula_loading tests/local-build.test.mjs
AGENTIX_TEST_HOMEBREW=1 node --test tests/local-install.test.mjs
```

The normal suite checks artifact snapshots, content identity, missing inputs,
profile/target selection, dependency declarations, Formula installation and
installed metadata, large-file integrity and compression failure cleanup. CI
also loads a 40 MiB fixture through Homebrew Ruby. To verify an existing binary,
set `AGENTIX_TEST_BINARY=/absolute/path/to/target/release/agentix` and run the
`supplied_release` or `homebrew_formula_loading` test by name. Set
`AGENTIX_TEST_SOURCE=/absolute/path/to/agentix` and run `existing_local_formulae`
to check the installed tap against both release binaries without installing or
linking them. `AGENTIX_TEST_RUBY=/absolute/path/to/ruby` selects the unit-test
runtime. The opt-in installation test builds a uniquely named Rust fixture outside
Homebrew, installs release/debug artifacts through the actual Formula recipe
starting with stable and HEAD kegs whose `opt` and command links diverge, with
its dependency declarations intact,
verifies no build dependencies and byte-for-byte binary reuse, checks
links/resources and loads metadata after
removing the checkout. It removes its fixture kegs and tap afterwards and never
starts Agentix or Taskix services.

To validate Ollaya against the real upstream release packages:

```sh
OLLAYA_TEST_HOMEBREW=1 node --test --test-name-pattern=real_homebrew tests/ollaya.test.mjs
```

This opt-in test downloads the release, checks Homebrew style/audit, installs a
uniquely named unlinked fixture, and runs the Formula's runtime-library and API
tests. On macOS it also starts a temporary Homebrew service on an unused port
with an isolated home/model directory, verifies its API, and stops it. The
fixture keg, tap, and service logs are removed afterwards. It does not download
models or change an existing Ollaya installation.
