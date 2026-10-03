import assert from "node:assert/strict";
import { test } from "node:test";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const formulaPath = new URL("../Formula/ollaya.rb", import.meta.url);
const assetNames = ["ollaya-darwin-arm64.tar.zst", "ollaya-darwin-arm64-mlx.tar.zst",
    "ollaya-linux-amd64.tar.zst", "ollaya-linux-arm64.tar.zst"];
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const currentFormula = await readFile(formulaPath, "utf8");
const currentVersion = currentFormula.match(/\/releases\/download\/v([^/]+)\//)[1];
const parts = currentVersion.split(".").map(Number);
const nextVersion = `${parts[0]}.${parts[1] + 1}.0`;
const nextTag = `v${nextVersion}`;

function upstream({ tag = nextTag, missing, corrupt, prerelease = false, draft = false, duplicate } = {}) {
    const bytes = new Map(assetNames.map(name => [name, Buffer.from(`archive ${name} ${tag}`)]));
    const base = `https://github.com/ollaya-dev/ollaya/releases/download/${tag}/`;
    const assets = [...assetNames, "sha256sum.txt"].filter(name => name !== missing)
        .map(name => ({ name, browser_download_url: base + name }));
    const manifest = assetNames.map(name => `${sha(bytes.get(name))}  ${name}`).join("\n") + "\n";
    const calls = [];
    const request = async url => {
        calls.push(url);
        if (url.startsWith("https://api.github.com/repos/ollaya-dev/ollaya/releases/")) {
            return new Response(JSON.stringify({ tag_name: tag, prerelease, draft, assets }));
        }
        if (url === base + "sha256sum.txt") return new Response(manifest + (duplicate ? manifest : ""));
        const name = url.slice(base.length);
        if (bytes.has(name)) return new Response(name === corrupt ? "corrupt archive" : bytes.get(name));
        throw new Error(`Unexpected URL: ${url}`);
    };
    return { request, bytes, calls };
}

test("ollaya_formula_preserves_runtime_libraries_and_registers_the_daemon", async () => {
    const formula = await readFile(formulaPath, "utf8");
    assert.doesNotMatch(formula, /^  version /m, "Homebrew infers the version from release URLs");
    for (const name of assetNames) assert.ok(formula.includes(name), name);
    assert.match(formula, /depends_on arch: :arm64/);
    assert.match(formula, /depends_on macos: :sonoma/);
    assert.match(formula, /bin.install "bin\/ollaya"/);
    assert.match(formula, /lib.install "lib\/ollaya"/);
    assert.match(formula, /resource\("mlx"\).stage/);
    assert.match(formula, /\(lib\/"ollaya"\).install "lib\/ollaya\/mlx_metal"/);
    assert.match(formula, /run \[opt_bin\/"ollaya", "serve"\]/);
    assert.match(formula, /keep_alive true/);
    assert.match(formula, /log_path var\/"log\/ollaya.log"/);
    assert.match(formula, /error_log_path var\/"log\/ollaya.err.log"/);
    assert.match(formula, /llama-devices/);
    assert.match(formula, /\/api\/version/);
    assert.match(formula, /--version 2>&1/, "Ollaya reports the client version on stderr without a daemon");
});

test("updates_all_archives_and_mlx_without_changing_service_or_install_logic", async () => {
    const { prepareUpdate } = await import("../scripts/update-ollaya.mjs");
    const formula = await readFile(formulaPath, "utf8");
    const source = upstream();
    const result = await prepareUpdate(formula, { request: source.request });
    assert.equal(result.version, nextVersion);
    assert.equal(result.changed, true);
    assert.match(source.calls[0], /\/releases\/latest$/);
    for (const name of assetNames) {
        assert.ok(result.formula.includes(`/${nextTag}/${name}`));
        assert.ok(result.formula.includes(sha(source.bytes.get(name))));
    }
    assert.equal(result.formula.split("  def install\n")[1], formula.split("  def install\n")[1]);
    const again = await prepareUpdate(result.formula, { request: source.request });
    assert.equal(again.changed, false);
});

test("homebrew_validates_all_platforms_before_and_after_an_ollaya_update", {
    skip: spawnSync("brew", ["--version"], { encoding: "utf8" }).status !== 0,
    timeout: 120_000,
}, async t => {
    const { prepareUpdate } = await import("../scripts/update-ollaya.mjs");
    const source = upstream();
    const updated = await prepareUpdate(currentFormula, { request: source.request });
    const directory = await mkdtemp(join(tmpdir(), "ollaya-platforms-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    for (const [formula, version] of [[currentFormula, currentVersion], [updated.formula, nextVersion]]) {
        const path = join(directory, "ollaya.rb");
        await writeFile(path, formula);
        const result = spawnSync("brew", ["ruby", "-e", `
require "formulary"
require "simulate_system"
systems = MacOSVersion::SYMBOLS.keys
systems << :linux
systems.each do |os|
  [:intel, :arm].each do |arch|
    Homebrew::SimulateSystem.with(os: os, arch: arch) do
      Formulary.clear_cache
      formula = Formulary.from_contents("ollaya", Pathname(ARGV.fetch(1)), File.read(ARGV.fetch(0)))
      puts JSON.generate(os: os, arch: arch, url: formula.stable.url,
                         arches: formula.requirements.grep(ArchRequirement).map(&:arch))
    end
  end
end
`, path, fileURLToPath(formulaPath)], { encoding: "utf8", timeout: 90_000,
            env: { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1" } });
        assert.equal(result.status, 0, result.stdout + result.stderr);
        const platforms = result.stdout.trim().split("\n").map(line => JSON.parse(line));
        assert.ok(platforms.some(platform => platform.os === "sonoma" && platform.arch === "intel"));
        for (const platform of platforms) {
            const archive = platform.os === "linux"
                ? `ollaya-linux-${platform.arch === "intel" ? "amd64" : "arm64"}.tar.zst`
                : "ollaya-darwin-arm64.tar.zst";
            assert.equal(platform.url, `https://github.com/ollaya-dev/ollaya/releases/download/v${version}/${archive}`);
            assert.deepEqual(platform.arches, platform.os === "linux" ? [] : ["arm64"],
                "macOS Intel validation must preserve the ARM-only installation requirement");
        }
    }
});

test("homebrew_accepts_ollaya_formula_component_order", {
    skip: spawnSync("brew", ["--version"], { encoding: "utf8" }).status !== 0,
    timeout: 180_000,
}, async t => {
    const directory = await mkdtemp(join(tmpdir(), "ollaya-style-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    await mkdir(join(directory, "Formula"));
    const path = join(directory, "Formula", "ollaya.rb");
    await writeFile(path, currentFormula);
    const result = spawnSync("brew", ["style", "--only-cops", "FormulaAudit/ComponentsOrder", path], {
        encoding: "utf8", timeout: 120_000,
        env: { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1" },
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /1 file inspected/);
});

test("explicit_version_is_normalized_and_resolved_as_a_release_tag", async () => {
    const { prepareUpdate } = await import("../scripts/update-ollaya.mjs");
    for (const version of [nextVersion, nextTag]) {
        const source = upstream();
        await prepareUpdate(await readFile(formulaPath, "utf8"), { version, request: source.request });
        assert.ok(source.calls[0].endsWith(`/releases/tags/${nextTag}`));
    }
});

for (const [name, options, error] of [
    ["missing archive", { missing: assetNames[2] }, /Missing release asset/],
    ["missing manifest", { missing: "sha256sum.txt" }, /Missing release asset/],
    ["corrupt archive", { corrupt: assetNames[1] }, /Checksum mismatch/],
    ["duplicate checksums", { duplicate: true }, /Duplicate checksum/],
    ["prerelease", { prerelease: true }, /stable release/],
    ["draft", { draft: true }, /stable release/],
    ["downgrade", { tag: "v0.0.0" }, /downgrade/],
]) {
    test(`rejects ${name} and leaves the_formula_unchanged`, async t => {
        const { updateFile } = await import("../scripts/update-ollaya.mjs");
        const dir = await mkdtemp(join(tmpdir(), "ollaya-update-"));
        t.after(() => rm(dir, { recursive: true, force: true }));
        const path = join(dir, "ollaya.rb");
        const formula = await readFile(formulaPath, "utf8");
        await writeFile(path, formula);
        await assert.rejects(updateFile(path, { request: upstream(options).request }), error);
        assert.equal(await readFile(path, "utf8"), formula);
    });
}

test("invalid_version_and_unexpected_formula_layout_fail_closed", async () => {
    const { prepareUpdate } = await import("../scripts/update-ollaya.mjs");
    const formula = await readFile(formulaPath, "utf8");
    for (const version of ["../main", "$(touch /tmp/no)", "0.10.0-rc.1"]) {
        await assert.rejects(prepareUpdate(formula, { version, request: upstream().request }), /Invalid version/);
    }
    await assert.rejects(prepareUpdate(formula.replace(assetNames[0], "unexpected.tgz"),
        { request: upstream().request }), /Unexpected Formula archive layout/);
});

test("manual_workflow_uses_environment_input_and_a_signed_pull_request", async () => {
    const workflow = await readFile(new URL("../.github/workflows/update-ollaya.yml", import.meta.url), "utf8");
    assert.match(workflow, /workflow_dispatch:/);
    assert.match(workflow, /version:\n/);
    assert.match(workflow, /OLLAYA_VERSION: \$\{\{ inputs.version \}\}/);
    assert.match(workflow, /node scripts\/update-ollaya.mjs/);
    assert.match(workflow, /node --test tests\/\*.test.mjs/);
    assert.match(workflow, /signoff: true/);
    assert.match(workflow, /base: main/);
    assert.match(workflow, /add-paths: Formula\/ollaya.rb/);
    assert.match(workflow, /branch: automation\/update-ollaya/);
    assert.doesNotMatch(workflow, /git push.*main|schedule:/);
});

test("real_homebrew_installs_runtime_and_starts_the_service", {
    skip: process.env.OLLAYA_TEST_HOMEBREW !== "1", timeout: 600_000,
}, async t => {
    const name = `ollaya-fixture-${process.pid}`;
    const tap = `codex-fixture/ollaya-${process.pid}`;
    const klass = name.split("-").map(word => word[0].toUpperCase() + word.slice(1)).join("");
    const directory = await mkdtemp(join(tmpdir(), "ollaya-homebrew-"));
    const env = { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_NO_INSTALL_CLEANUP: "1",
        HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: "1", HOMEBREW_NO_ENV_HINTS: "1" };
    const brew = (...args) => execFileSync("brew", args, { env, encoding: "utf8", timeout: 300_000 });
    const tapPath = brew("--repository", tap).trim();
    const server = createServer();
    await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
    const port = server.address().port;
    await new Promise(resolve => server.close(resolve));
    let serviceStarted = false;
    try {
        await mkdir(join(tapPath, "Formula"), { recursive: true });
        execFileSync("git", ["init", "--quiet", "--initial-branch=test/ollaya-fixture", tapPath]);
        const formula = currentFormula.replace("class Ollaya <", `class ${klass} <`);
        const fixturePath = join(tapPath, "Formula", `${name}.rb`);
        await writeFile(fixturePath, formula);
        execFileSync("git", ["-C", tapPath, "add", "Formula"]);
        brew("trust", tap);
        const style = brew("style", "--formula", `${tap}/${name}`);
        assert.match(style, /1 file inspected/);
        brew("audit", "--strict", `${tap}/${name}`);
        // Only the disposable service gets an isolated home, model store, port, and logs.
        await writeFile(fixturePath, formula
            .replace('    keep_alive true', `    keep_alive true\n    environment_variables OLLAYA_HOST: "127.0.0.1:${port}", HOME: "${directory}"`)
            .replaceAll('var/"log/ollaya', `var/"log/${name}`));
        brew("install", "--skip-link", `${tap}/${name}`);
        const prefix = brew("--prefix", `${tap}/${name}`).trim();
        const versionCheck = spawnSync(join(prefix, "bin/ollaya"), ["--version"], { encoding: "utf8" });
        assert.equal(versionCheck.status, 0, versionCheck.stderr);
        assert.ok((versionCheck.stdout + versionCheck.stderr).includes(currentVersion));
        brew("test", "--force", `${tap}/${name}`);
        const metadata = JSON.parse(brew("info", "--json=v2", `${tap}/${name}`));
        assert.equal(metadata.formulae[0].service.run.at(-1), "serve");
        if (process.platform === "darwin") {
            serviceStarted = true;
            brew("services", "start", `${tap}/${name}`);
            let result;
            for (let i = 0; i < 30; i++) {
                try {
                    const response = await fetch(`http://127.0.0.1:${port}/api/version`);
                    result = await response.json();
                    break;
                } catch {
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
            }
            assert.equal(result?.version, currentVersion);
            const services = JSON.parse(brew("services", "list", "--json"));
            assert.equal(services.find(service => service.name === name)?.status, "started");
        }
    } finally {
        if (serviceStarted) brew("services", "stop", `${tap}/${name}`);
        try { brew("uninstall", "--force", `${tap}/${name}`); } catch { /* Installation may have failed. */ }
        try { brew("untap", tap); } catch { /* Only this test's disposable tap is removed. */ }
        await rm(tapPath, { recursive: true, force: true });
        await rm(directory, { recursive: true, force: true });
        const brewPrefix = brew("--prefix").trim();
        for (const suffix of [".log", ".err.log"]) await rm(join(brewPrefix, "var/log", name + suffix), { force: true });
    }
});
