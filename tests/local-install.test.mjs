import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
test("real_homebrew_installs_prebuilt_local_binaries_without_build_dependencies", {
    skip: process.env.AGENTIX_TEST_HOMEBREW !== "1", timeout: 300_000,
}, async () => {
    const dir = await mkdtemp(join(tmpdir(), "brew-artifact-acceptance-"));
    const source = join(dir, "local source");
    const name = `agentix-source-fixture-${process.pid}`;
    const tap = `codex-fixture/source-${process.pid}`;
    const env = {...process.env, HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_NO_INSTALL_CLEANUP: "1", HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: "1", HOMEBREW_AGENTIX_LOCAL_SOURCE: "", HOMEBREW_AGENTIX_LOCAL_TARGET_DIR: ""};
    const brew = (args, extra = {}) => execFileSync("brew", args, {env: {...env, ...extra}, encoding: "utf8", timeout: 90_000, killSignal: "SIGKILL"});
    let tapPath;
    const snapshots = new Set();
    try {
        tapPath = brew(["--repository", tap]).trim();
        await mkdir(join(tapPath, "Formula"), {recursive: true});
        await mkdir(join(tapPath, "lib"));
        await writeFile(join(tapPath, "lib", "agentix_local_build.rb"), await readFile(join(root, "lib", "agentix_local_build.rb")));
        execFileSync("git", ["init", "--quiet", "--initial-branch=test/local-source", tapPath]);
        for (const path of ["config", "completions", ".github/scripts", `crates/${name}/src`]) await mkdir(join(source, path), {recursive: true});
        await writeFile(join(source, "Cargo.toml"), `[workspace]\nmembers = ["crates/${name}"]\nresolver = "2"\n`);
        await writeFile(join(source, `crates/${name}/Cargo.toml`), `[package]\nname = "${name}"\nversion = "1.2.3"\nedition = "2021"\n`);
        const main = join(source, `crates/${name}/src/main.rs`);
        await writeFile(main, `fn main() { println!("${name} 1.2.3"); }\n`);
        execFileSync("cargo", ["generate-lockfile", "--manifest-path", join(source, "Cargo.toml")]);
        await writeFile(join(source, ".github/scripts/set-release-version.sh"), "exit 91\n");
        await writeFile(join(source, "config", `${name}.example.toml`), "fixture = true\n");
        for (const file of [`${name}.bash`, `_${name}`, `${name}.fish`]) await writeFile(join(source, "completions", file), "# fixture\n");
        execFileSync("git", ["init", "--quiet", source]);
        execFileSync("git", ["-C", source, "add", "."]);
        const archive = join(dir, "source-1.2.3.tar.gz");
        execFileSync("tar", ["-czf", archive, "--exclude=.git", "-C", source, "."]);
        const checksum = createHash("sha256").update(await readFile(archive)).digest("hex");
        const klass = name.split("-").map(word => word[0].toUpperCase() + word.slice(1)).join("");
        const template = await readFile(join(root, "Formula/agentix.rb"), "utf8");
        const formula = template.replaceAll("agentix", name).replace("class Agentix", `class ${klass}`)
            .replaceAll(`${name}_local_build.rb`, "agentix_local_build.rb")
            .replace(/  url "[^"\n]+"/, `  url "file://${archive}"`)
            .replace(/  sha256 "[a-f0-9]+"/, `  sha256 "${checksum}"`)
            .replace(/  bottle do\n.*?  end\n/s, "");
        const formulaPath = join(tapPath, "Formula", `${name}.rb`);
        await writeFile(formulaPath, formula);
        brew(["trust", tap]);
        const prefix = brew(["--prefix"]).trim();
        const command = join(prefix, "bin", name);
        for (const [iteration, profile] of [[1, "release"], [2, "release"], [3, "debug"]]) {
            const text = `fn main() { println!("${name} dirty-${iteration}-{}", if cfg!(debug_assertions) { "debug" } else { "release" }); }\n`;
            await writeFile(main, text);
            const local = {HOMEBREW_AGENTIX_LOCAL_SOURCE: source, HOMEBREW_AGENTIX_LOCAL_PROFILE: profile};
            // Compile outside Homebrew, exactly as make release/make does.
            execFileSync("cargo", ["build", "--manifest-path", join(source, "Cargo.toml"), ...(profile === "release" ? ["--release"] : [])]);
            const binary = join(source, "target", profile, name);
            const expectedBinary = await readFile(binary);
            const deps = JSON.parse(brew(["info", "--json=v2", `${tap}/${name}`], local)).formulae[0];
            assert.deepEqual(deps.build_dependencies, []);
            assert.deepEqual(deps.dependencies, []);
            brew(["reinstall", "--build-from-source", `${tap}/${name}`], local);
            assert.equal(execFileSync(command, ["--version"], {encoding: "utf8"}).trim(), `${name} dirty-${iteration}-${profile}`);
            assert.equal(await readFile(main, "utf8"), text);
            assert.equal(await readFile(formulaPath, "utf8"), formula);
            const keg = await realpath(join(prefix, "opt", name));
            assert.match(keg, new RegExp(`0\\.0\\.0-local\\..*\\.${profile}$`));
            assert.equal(await realpath(command), join(keg, "bin", name));
            assert.deepEqual(await readFile(command), expectedBinary);
            assert.equal(await readFile(join(keg, "share", name, `${name}.example.toml`), "utf8"), "fixture = true\n");
            const record = JSON.parse(await readFile(join(keg, "share", name, "agentix-local.json"), "utf8"));
            assert.equal(record.profile, profile);
            snapshots.add(fileURLToPath(record.url));
            brew(["linkage", "--test", `${tap}/${name}`]);
        }
        await rm(source, {recursive: true});
        const installed = await realpath(join(prefix, "opt", name));
        const info = brew(["ruby", "-e", 'require "formulary"; f = Formulary.factory(Pathname(ARGV[0])); abort unless f.version.to_s.include?("local"); puts f.version', join(installed, ".brew", `${name}.rb`)]);
        assert.match(info, /local/);
    } finally {
        try { brew(["uninstall", "--force", `${tap}/${name}`]); } catch { /* Setup may have failed. */ }
        try { brew(["untrust", "--formula", `${tap}/${name}`]); brew(["untrust", tap]); } catch { /* Setup may have failed. */ }
        if (tapPath) await rm(tapPath, {recursive: true, force: true});
        for (const archive of snapshots) await rm(archive, {force: true});
        await rm(dir, {recursive: true, force: true});
    }
});
