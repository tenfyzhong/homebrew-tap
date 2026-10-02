import assert from "node:assert/strict";
import { test } from "node:test";
import { chmod, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const helper = process.env.AGENTIX_TEST_HELPER || join(root, "lib/agentix_local_build.rb");
const ruby = process.env.AGENTIX_TEST_RUBY || "ruby";
const rubyArgs = ruby === "brew" ? ["ruby"] : [];
test("existing_local_formulae_load_with_precompiled_release_artifacts", {
    skip: !process.env.AGENTIX_TEST_SOURCE,
}, () => {
    for (const name of ["taskix", "agentix"]) {
        const result = spawnSync("brew", ["ruby", "-e", `require "formulary"; puts Formulary.factory("tenfyzhong/tap/${name}", :stable).pkg_version`], {encoding: "utf8", env: {...process.env, HOMEBREW_AGENTIX_LOCAL_SOURCE: process.env.AGENTIX_TEST_SOURCE, HOMEBREW_AGENTIX_LOCAL_PROFILE: "release", HOMEBREW_NO_AUTO_UPDATE: "1"}, timeout: 90_000});
        assert.equal(result.status, 0, result.stderr);
        assert.match(result.stdout.trim(), /^0\.0\.0-local\..*\.release$/);
    }
});
const script = `require "json"
require ARGV.shift
class Spec
  @values = {url: "upstream", version: "1.2.3", sha256: "upstream-sha"}
  class << self
    attr_reader :values
    def url(value); @values[:url] = value; end
    def version(value); @values[:version] = value; end
    def sha256(value); @values[:sha256] = value; end
  end
end
AgentixLocalBuild.configure(Spec, "agentix", ARGV[0])
puts JSON.generate({spec: Spec.values, snapshot: AgentixLocalBuild.snapshot("agentix", ARGV[0])})
`;
async function fixture(t) {
    const dir = await mkdtemp(join(tmpdir(), "tap-artifact-"));
    t.after(() => rm(dir, {recursive: true, force: true}));
    const source = join(dir, "source dir");
    for (const path of ["config", "completions", "target/release", "target/debug"]) await mkdir(join(source, path), {recursive: true});
    await writeFile(join(source, "Cargo.toml"), '[workspace]\nmembers = []\n');
    await writeFile(join(source, "modified.rs"), "uncompiled source\n");
    for (const name of ["agentix", "taskix"]) {
        for (const profile of ["release", "debug"]) {
            const path = join(source, "target", profile, name);
            await writeFile(path, `${name} ${profile} binary\n`);
            await chmod(path, 0o755);
        }
        for (const path of [`config/${name}.example.toml`, `completions/${name}.bash`, `completions/_${name}`, `completions/${name}.fish`]) await writeFile(join(source, path), "# fixture\n");
    }
    const env = (sourcePath = source, profile = "release", target = "") => ({...process.env, HOMEBREW_AGENTIX_LOCAL_SOURCE: sourcePath, HOMEBREW_AGENTIX_LOCAL_PROFILE: profile, HOMEBREW_AGENTIX_LOCAL_TARGET_DIR: target, HOMEBREW_CACHE: join(dir, "cache")});
    const run = (sourcePath = source, profile = "release", formulaDir = join(dir, "Formula"), target = "") => spawnSync(ruby, [...rubyArgs, "-e", script, helper, formulaDir], {encoding: "utf8", env: env(sourcePath, profile, target)});
    return {dir, source, run, env};
}

test("formula_snapshots_selected_prebuilt_binary_and_resources", async t => {
    const f = await fixture(t);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(result.stdout);
    assert.match(data.spec.version, /^0\.0\.0-local\..*\.release$/);
    const unpack = join(f.dir, "unpack");
    await mkdir(unpack);
    execFileSync("tar", ["-xzf", fileURLToPath(data.spec.url), "-C", unpack]);
    assert.equal(await readFile(join(unpack, "bin/agentix"), "utf8"), "agentix release binary\n");
    assert.equal(await readFile(join(unpack, "config/agentix.example.toml"), "utf8"), "# fixture\n");
    const listing = execFileSync("tar", ["-tzf", fileURLToPath(data.spec.url)], {encoding: "utf8"});
    assert.doesNotMatch(listing, /target\/|modified\.rs|Cargo.toml|taskix/);
});

function largeBinary() {
    const binary = Buffer.alloc(40 * 1024 * 1024 + 17);
    let state = 0x12345678;
    for (let i = 0; i < binary.length; i++) {
        state ^= state << 13;
        state ^= state >>> 17;
        state ^= state << 5;
        binary[i] = i % 4 === 3 ? 0x94 : state & 0xff;
    }
    return binary;
}

test("large_binary_snapshot_preserves_bytes_and_reproducible_identity", async t => {
    const f = await fixture(t);
    const binary = largeBinary();
    await writeFile(join(f.source, "target/release/agentix"), binary);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(result.stdout);
    const unpack = join(f.dir, "unpack");
    await mkdir(unpack);
    execFileSync("tar", ["-xzf", fileURLToPath(data.spec.url), "-C", unpack]);
    assert.deepEqual(await readFile(join(unpack, "bin/agentix")), binary);
    const again = f.run();
    assert.equal(again.status, 0, again.stderr);
    assert.deepEqual(JSON.parse(again.stdout), data);
});

test("compression_failure_cleans_temporary_files_and_restores_epoch", async t => {
    const f = await fixture(t);
    const bin = join(f.dir, "bin");
    await mkdir(bin);
    const gzip = join(bin, "gzip");
    await writeFile(gzip, "#!/bin/sh\nexit 7\n");
    await chmod(gzip, 0o755);
    const result = spawnSync(ruby, [...rubyArgs, "-e", 'require ARGV.shift; begin; AgentixLocalBuild.snapshot("agentix", "."); rescue => e; puts JSON.generate({error: e.message, epoch: ENV["SOURCE_DATE_EPOCH"]}); end', helper], {encoding: "utf8", env: {...f.env(), PATH: `${bin}:${process.env.PATH}`, SOURCE_DATE_EPOCH: "123"}});
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {error: "Failed to compress local artifact snapshot with gzip", epoch: "123"});
    assert.deepEqual(await readdir(join(f.dir, "cache", "agentix-local-artifacts")), []);
});

test("supplied_release_binary_snapshots_under_homebrew_runtime", {
    skip: !process.env.AGENTIX_TEST_BINARY,
}, async t => {
    const f = await fixture(t);
    const binary = await readFile(process.env.AGENTIX_TEST_BINARY);
    await writeFile(join(f.source, "target/release/agentix"), binary);
    const result = spawnSync("brew", ["ruby", "-e", 'require ARGV.shift; 10.times { AgentixLocalBuild.instance_variable_set(:@snapshots, {}); puts JSON.generate({spec: AgentixLocalBuild.snapshot("agentix", ".")}) }', helper], {encoding: "utf8", env: {...f.env(), HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_NO_INSTALL_FROM_API: "1"}, timeout: 90_000});
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(result.stdout.trim().split("\n").at(-1));
    const unpack = join(f.dir, "unpack");
    await mkdir(unpack);
    execFileSync("tar", ["-xzf", fileURLToPath(data.spec.url), "-C", unpack]);
    assert.deepEqual(await readFile(join(unpack, "bin/agentix")), binary);
});

test("homebrew_formula_loading_snapshots_release_binary", {
    skip: process.env.AGENTIX_TEST_HOMEBREW !== "1",
}, async t => {
    const f = await fixture(t);
    await writeFile(join(f.source, "target/release/agentix"), process.env.AGENTIX_TEST_BINARY ? await readFile(process.env.AGENTIX_TEST_BINARY) : largeBinary());
    const tap = `codex-fixture/snapshot-${process.pid}`;
    const tapPath = execFileSync("brew", ["--repository", tap], {encoding: "utf8"}).trim();
    await mkdir(join(tapPath, "Formula"), {recursive: true});
    t.after(() => rm(tapPath, {recursive: true, force: true}));
    execFileSync("git", ["init", "--quiet", "--initial-branch=test/snapshot", tapPath]);
    execFileSync("brew", ["trust", tap], {env: {...process.env, HOMEBREW_NO_AUTO_UPDATE: "1"}});
    const formula = join(tapPath, "Formula", "agentix.rb");
    await writeFile(formula, `require ${JSON.stringify(helper)}\nclass Agentix < Formula\n  desc "Snapshot fixture"\n  homepage "https://example.invalid"\n  url "https://example.invalid/agentix-1.2.3.tar.gz"\n  sha256 "${"0".repeat(64)}"\n  AgentixLocalBuild.configure(self, "agentix", __dir__)\nend\n`);
    const result = spawnSync("brew", ["ruby", "-e", 'require "formulary"; 2.times { Formulary.clear_cache; AgentixLocalBuild.instance_variable_set(:@snapshots, {}) if defined?(AgentixLocalBuild); f = Formulary.factory(Pathname(ARGV[0]), :stable); puts JSON.generate({url: f.stable.url, version: f.pkg_version.to_s}) }', formula], {encoding: "utf8", env: {...f.env(), HOMEBREW_NO_INSTALL_FROM_API: "1", HOMEBREW_NO_AUTO_UPDATE: "1"}, timeout: 90_000});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(new Set(result.stdout.trim().split("\n")).size, 1);
    const data = JSON.parse(result.stdout.trim().split("\n").at(-1));
    const unpack = join(f.dir, "unpack");
    await mkdir(unpack);
    execFileSync("tar", ["-xzf", fileURLToPath(data.url), "-C", unpack]);
    assert.deepEqual(await readFile(join(unpack, "bin/agentix")), await readFile(join(f.source, "target/release/agentix")));
});

test("artifact_identity_changes_with_binary_or_resource_but_not_uncompiled_source", async t => {
    const f = await fixture(t);
    const first = JSON.parse(f.run().stdout);
    assert.deepEqual(JSON.parse(f.run().stdout), first);
    await writeFile(join(f.source, "modified.rs"), "new uncompiled source\n");
    assert.deepEqual(JSON.parse(f.run().stdout), first);
    await writeFile(join(f.source, "target/release/agentix"), "changed binary\n");
    const second = JSON.parse(f.run().stdout);
    assert.notEqual(second.spec.version, first.spec.version);
    await writeFile(join(f.source, "completions/agentix.bash"), "changed completion\n");
    assert.notEqual(JSON.parse(f.run().stdout).spec.version, second.spec.version);
});

test("debug_profile_snapshots_debug_binary_with_separate_identity", async t => {
    const f = await fixture(t);
    const release = JSON.parse(f.run().stdout);
    const result = f.run(f.source, "debug");
    assert.equal(result.status, 0, result.stderr);
    const debug = JSON.parse(result.stdout);
    assert.notEqual(debug.spec.version, release.spec.version);
    assert.match(execFileSync("tar", ["-xOzf", fileURLToPath(debug.spec.url), "bin/agentix"], {encoding: "utf8"}), /debug binary/);
});

test("custom_target_directory_is_supported", async t => {
    const f = await fixture(t);
    const target = join(f.dir, "custom target");
    await mkdir(join(target, "release"), {recursive: true});
    await writeFile(join(target, "release/agentix"), "custom binary\n");
    await chmod(join(target, "release/agentix"), 0o755);
    const result = f.run(f.source, "release", join(f.dir, "Formula"), target);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(execFileSync("tar", ["-xOzf", fileURLToPath(JSON.parse(result.stdout).spec.url), "bin/agentix"], {encoding: "utf8"}), "custom binary\n");
});

test("upstream_formula_is_unchanged_without_local_input", async t => {
    const f = await fixture(t);
    const result = f.run("");
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {spec: {url: "upstream", version: "1.2.3", sha256: "upstream-sha"}, snapshot: null});
});

for (const label of ["missing_binary", "nonexecutable_binary", "missing_resource", "invalid_profile"]) {
    test(`formula_rejects_${label}_before_installation`, async t => {
        const f = await fixture(t);
        if (label === "missing_binary") await rm(join(f.source, "target/release/agentix"));
        if (label === "nonexecutable_binary") await chmod(join(f.source, "target/release/agentix"), 0o644);
        if (label === "missing_resource") await rm(join(f.source, "completions/_agentix"));
        const result = f.run(f.source, label === "invalid_profile" ? "bad" : "release");
        assert.notEqual(result.status, 0);
        assert.match(result.stderr, /binary|resource|profile/i);
    });
}

test("installed_formula_reads_snapshot_without_original_checkout", async t => {
    const f = await fixture(t);
    const data = JSON.parse(f.run().stdout).snapshot;
    await mkdir(join(f.dir, "share/agentix"), {recursive: true});
    await writeFile(join(f.dir, "share/agentix/agentix-local.json"), JSON.stringify(data));
    await rm(f.source, {recursive: true});
    const result = f.run("", "release", join(f.dir, ".brew"));
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout).snapshot, data);
});

const formulaScript = `require "pathname"
require "json"
class Destination
  def initialize(kind); @kind = kind; end
  def install(*args); ($events ||= []) << [@kind, args.map(&:to_s)]; end
end
class Formula
  def self.inherited(klass); klass.instance_variable_set(:@deps, []); end
  def self.deps; @deps; end
  def self.head(url, **options); @head = {url: url, options: options}; end
  def self.head_spec; @head; end
  def self.depends_on(spec); @deps << spec.keys.first; end
  def self.method_missing(*); end
  def self.bottle; end
  def self.service; end
  def self.test; end
  def build; Struct.new(:head?).new(false); end
  def buildpath; Pathname(ENV.fetch("TEST_BUILDPATH")); end
  def pkgshare; Destination.new("share"); end
  def bin; Destination.new("bin"); end
  def bash_completion; Destination.new("bash"); end
  def zsh_completion; Destination.new("zsh"); end
  def fish_completion; Destination.new("fish"); end
  def std_cargo_args(**); []; end
  def system(*); raise "Unexpected compilation in local install"; end
end
load ARGV.shift
klass = Object.const_get(ARGV.shift)
klass.new.install if ENV["TEST_INSTALL"] == "1"
puts JSON.generate({dependencies: klass.deps, head: klass.head_spec, events: $events || []})
`;
for (const name of ["agentix", "taskix"]) {
    test(`${name}_local_recipe_has_no_build_dependencies_and_installs_binary`, async t => {
        const f = await fixture(t);
        const result = spawnSync("ruby", ["-e", formulaScript, join(root, `Formula/${name}.rb`), name === "agentix" ? "Agentix" : "Taskix"], {encoding: "utf8", env: {...f.env(), TEST_BUILDPATH: f.dir, TEST_INSTALL: "1"}});
        assert.equal(result.status, 0, result.stderr);
        const data = JSON.parse(result.stdout);
        assert.deepEqual(data.dependencies, []);
        assert.equal(data.head, null, "Local artifacts must not inherit an installed remote HEAD spec");
        assert.ok(data.events.some(([kind, paths]) => kind === "bin" && paths.includes(`bin/${name}`)));
        assert.ok(data.events.some(([kind]) => kind === "fish"));
    });
    test(`${name}_upstream_recipe_retains_build_dependencies`, async t => {
        const f = await fixture(t);
        const result = spawnSync("ruby", ["-e", formulaScript, join(root, `Formula/${name}.rb`), name === "agentix" ? "Agentix" : "Taskix"], {encoding: "utf8", env: {...f.env(""), TEST_INSTALL: "0"}});
        assert.equal(result.status, 0, result.stderr);
        const data = JSON.parse(result.stdout);
        assert.deepEqual(data.dependencies, name === "agentix" ? ["protobuf", "rust"] : ["rust"]);
        assert.deepEqual(data.head, {url: "https://github.com/tenfyzhong/agentix.git", options: {branch: "main"}});
    });
}

test("missing_input_preserves_source_date_epoch", async t => {
    const f = await fixture(t);
    await rm(join(f.source, "target/release/agentix"));
    const result = spawnSync("ruby", ["-e", 'require ARGV.shift; begin; AgentixLocalBuild.snapshot("agentix", ARGV.shift); rescue; puts ENV["SOURCE_DATE_EPOCH"]; end', helper, join(f.dir, "Formula")], {encoding: "utf8", env: {...f.env(), SOURCE_DATE_EPOCH: "123"}});
    assert.equal(result.stdout.trim(), "123");
});
