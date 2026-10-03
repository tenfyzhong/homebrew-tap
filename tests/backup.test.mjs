import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("backup_formula_installs_a_standalone_command_with_python_and_rclone", async () => {
    const formula = await readFile(new URL("../Formula/taskix-backup.rb", import.meta.url), "utf8");
    assert.match(formula, /class TaskixBackup < Formula/);
    assert.match(formula, /depends_on "python@3\.14"/);
    assert.match(formula, /depends_on "rclone"/);
    assert.match(formula, /rewrite_shebang.*scripts\/taskix-backup\.py/);
    assert.match(formula, /bin.install "scripts\/taskix-backup\.py" => "taskix-backup"/);
    assert.doesNotMatch(formula, /depends_on "(?:taskix|agentix|rust)"|service do|post_install/);
    assert.match(formula, /--restore/);
    assert.match(formula, /type = local/);
    assert.match(formula, /SELECT value FROM evidence/);
});

test("real_homebrew_installs_and_pours_the_backup_formula_and_round_trips_a_database", {
    skip: process.env.AGENTIX_TEST_HOMEBREW !== "1", timeout: 300_000,
}, async () => {
    assert.ok(process.env.AGENTIX_TEST_SOURCE, "Set AGENTIX_TEST_SOURCE to the Agentix checkout");
    const directory = await mkdtemp(join(tmpdir(), "backup-formula-"));
    const source = process.env.AGENTIX_TEST_SOURCE;
    const name = `taskix-backup-fixture-${process.pid}`;
    const tap = `codex-fixture/backup-${process.pid}`;
    const env = { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_NO_INSTALL_CLEANUP: "1",
        HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: "1", HOMEBREW_NO_ENV_HINTS: "1" };
    const brew = (...args) => execFileSync("brew", args, { env, encoding: "utf8", timeout: 240_000 });
    let tapPath;
    try {
        tapPath = brew("--repository", tap).trim();
        await mkdir(join(tapPath, "Formula"), { recursive: true });
        execFileSync("git", ["init", "--quiet", "--initial-branch=test/backup-fixture", tapPath]);
        await mkdir(join(directory, "source/scripts"), { recursive: true });
        await writeFile(join(directory, "source/scripts/taskix-backup.py"), await readFile(join(source, "scripts/taskix-backup.py")));
        await writeFile(join(directory, "source/LICENSE"), await readFile(join(source, "LICENSE")));
        const archive = join(directory, "source-1.2.3.tar.gz");
        execFileSync("tar", ["-czf", archive, "-C", join(directory, "source"), "."]);
        const digest = createHash("sha256").update(await readFile(archive)).digest("hex");
        const klass = name.split("-").map(word => word[0].toUpperCase() + word.slice(1)).join("");
        const template = await readFile(new URL("../Formula/taskix-backup.rb", import.meta.url), "utf8");
        const formula = template.replace("class TaskixBackup", `class ${klass}`)
            .replace(/  head .*\n/, `  url "file://${archive}"\n  sha256 "${digest}"\n`)
            .replaceAll('"taskix-backup"', `"${name}"`)
            .replaceAll("#{bin}/taskix-backup", `#{bin}/${name}`);
        const prepared = join(directory, `${name}.rb`);
        await writeFile(prepared, formula);
        await writeFile(join(tapPath, "Formula", `${name}.rb`), formula);
        brew("trust", tap);
        brew("style", "--formula", `${tap}/${name}`);
        const result = spawnSync("bash", [join(source, ".github/scripts/build-homebrew-bottle.sh")], {
            cwd: directory, encoding: "utf8", timeout: 240_000,
            env: { ...env, FORMULA: name, FORMULA_PATH: prepared, BOTTLE_INSTALL_KIND: "script", TAP_NAME: tap,
                RELEASE_TAG: "1.2.3", BOTTLE_ROOT_URL: "https://example.invalid/releases/1.2.3" },
        });
        assert.equal(result.status, 0, result.stdout + result.stderr);
        const prefix = brew("--prefix", `${tap}/${name}`).trim();
        const installed = await readFile(join(prefix, "bin", name), "utf8");
        const python = brew("--prefix", "python@3.14").trim();
        assert.ok(installed.startsWith(`#!${python}/bin/python3.14\n`), installed.split("\n")[0]);
        assert.equal(await readFile(join(prefix, ".brew", `${name}.rb`), "utf8"), formula);
        assert.equal(await readFile(join(tapPath, "Formula", `${name}.rb`), "utf8"), formula);
        assert.match(execFileSync(join(prefix, "bin", name), ["--help"], { encoding: "utf8" }), /--restore/);
    } finally {
        if (tapPath) {
            try { brew("uninstall", "--force", `${tap}/${name}`); } catch { /* An install may have failed before a keg existed. */ }
            try { brew("untap", tap); } catch { /* Remove only this test's disposable tap. */ }
            await rm(tapPath, { recursive: true, force: true });
        }
        await rm(directory, { recursive: true, force: true });
    }
});
