import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const helper = fileURLToPath(new URL("../lib/agentix_local_build.rb", import.meta.url));
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
puts JSON.generate({spec: Spec.values, snapshot: AgentixLocalBuild.snapshot("agentix", ARGV[0]), cargo: AgentixLocalBuild.cargo_args("agentix", ARGV[0])})
`;
async function fixture(t) {
    const dir = await mkdtemp(join(tmpdir(), "tap-source-"));
    t.after(() => rm(dir, {recursive: true, force: true}));
    const source = join(dir, "source dir");
    await mkdir(source);
    await writeFile(join(source, "Cargo.toml"), '[workspace]\nmembers = []\n');
    await writeFile(join(source, "modified.rs"), "uncommitted source\n");
    await writeFile(join(source, ".gitignore"), "target/\nnode_modules/\n");
    execFileSync("git", ["init", "--quiet", source]);
    execFileSync("git", ["-C", source, "add", "."]);
    await writeFile(join(source, "modified.rs"), "dirty source\n");
    await writeFile(join(source, "untracked.rs"), "new source\n");
    for (const path of ["target", "node_modules"]) {
        await mkdir(join(source, path));
        await writeFile(join(source, path, "excluded"), "ignored build output");
    }
    const run = (sourcePath = source, profile = "release", formulaDir = join(dir, "Formula")) => spawnSync("ruby", ["-e", script, helper, formulaDir], {
        encoding: "utf8", env: {...process.env, HOMEBREW_AGENTIX_LOCAL_MANIFEST: "", HOMEBREW_AGENTIX_LOCAL_SOURCE: sourcePath, HOMEBREW_AGENTIX_LOCAL_PROFILE: profile, HOMEBREW_CACHE: join(dir, "cache")},
    });
    return {dir, source, run};
}

test("formula_snapshots_dirty_local_source_and_excludes_build_outputs", async t => {
    const f = await fixture(t);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(result.stdout);
    assert.match(data.spec.version, /^0\.0\.0-local\./);
    assert.equal(data.snapshot.profile, "release");
    assert.deepEqual(data.cargo, ["--all-features"]);
    const unpack = join(f.dir, "unpack");
    await mkdir(unpack);
    execFileSync("tar", ["-xzf", fileURLToPath(data.spec.url), "-C", unpack]);
    assert.equal(await readFile(join(unpack, "modified.rs"), "utf8"), "dirty source\n");
    assert.equal(await readFile(join(unpack, "untracked.rs"), "utf8"), "new source\n");
    const listing = execFileSync("tar", ["-tzf", fileURLToPath(data.spec.url)], {encoding: "utf8"});
    assert.doesNotMatch(listing, /target\/|node_modules\/|\.git\//);
    assert.equal(await readFile(join(f.source, "modified.rs"), "utf8"), "dirty source\n");
});

test("source_snapshot_is_stable_and_changes_when_source_changes", async t => {
    const f = await fixture(t);
    const first = JSON.parse(f.run().stdout);
    assert.deepEqual(JSON.parse(f.run().stdout), first);
    await writeFile(join(f.source, "untracked.rs"), "newer source\n");
    assert.notEqual(JSON.parse(f.run().stdout).spec.version, first.spec.version);
});

test("debug_profile_is_built_by_formula_and_has_separate_identity", async t => {
    const f = await fixture(t);
    const release = JSON.parse(f.run().stdout);
    const result = f.run(f.source, "debug");
    assert.equal(result.status, 0, result.stderr);
    const debug = JSON.parse(result.stdout);
    assert.deepEqual(debug.cargo, ["--all-features", "--debug"]);
    assert.notEqual(debug.spec.version, release.spec.version);
});

test("upstream_formula_is_unchanged_without_local_source", async t => {
    const f = await fixture(t);
    const result = f.run("");
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {spec: {url: "upstream", version: "1.2.3", sha256: "upstream-sha"}, snapshot: null, cargo: []});
});

for (const [label, source, profile] of [["missing_source", "missing", "release"], ["invalid_profile", "source", "bad"]]) {
    test(`formula_rejects_${label}_before_installation`, async t => {
        const f = await fixture(t);
        const result = f.run(source === "source" ? f.source : join(f.dir, source), profile);
        assert.notEqual(result.status, 0);
        assert.match(result.stderr, /local source|profile/i);
    });
}

test("installed_formula_reads_snapshot_without_original_checkout", async t => {
    const f = await fixture(t);
    const data = JSON.parse(f.run().stdout).snapshot;
    await mkdir(join(f.dir, "share", "agentix"), {recursive: true});
    await writeFile(join(f.dir, "share", "agentix", "agentix-local.json"), JSON.stringify(data));
    await rm(f.source, {recursive: true});
    const result = f.run("", "release", join(f.dir, ".brew"));
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout).snapshot, data);
});
