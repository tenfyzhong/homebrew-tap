import assert from "node:assert/strict";
import { test } from "node:test";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const workflow = await readFile(new URL("../.github/workflows/tests.yml", import.meta.url), "utf8");

test("CI Homebrew loads JSON without the shared Bootsnap cache", {
    skip: spawnSync("brew", ["--version"]).status !== 0,
    timeout: 120_000,
}, () => {
    const env = { ...process.env };
    delete env.HOMEBREW_NO_BOOTSNAP;
    const globalEnv = workflow.split("\nenv:\n")[1].split(/\n\S/)[0];
    for (const [, key, value] of globalEnv.matchAll(/^  (HOMEBREW_\w+): (.+)$/gm)) {
        env[key] = value;
    }
    const result = spawnSync("brew", ["ruby", "-e", `
require "json"
puts JSON.generate({ bootsnap_loaded: !!defined?(::Bootsnap), value: JSON.parse('{"ok":true}') })
`], { encoding: "utf8", env, timeout: 90_000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { bootsnap_loaded: false, value: { ok: true } });
});

function stepScript(name) {
    const step = workflow.split(`      - name: ${name}\n`)[1].split("\n      - ")[0];
    const inline = step.match(/        run: ([^|\n].*)/);
    return inline ? inline[1] : step.split("        run: |\n")[1].replace(/^          /gm, "");
}
for (const formulae of ["tenfyzhong/tap/agentix", "tenfyzhong/tap/agentix,tenfyzhong/tap/taskix"]) {
    for (const step of ["Select formula versions", "Audit formulae"]) {
        test(`${step} passes separate formula arguments for ${formulae}`, async () => {
            const dir = await mkdtemp(join(tmpdir(), "tap-workflow-"));
            try {
                const args = join(dir, "args");
                await writeFile(join(dir, "brew"), '#!/bin/bash\nprintf "%s\\n" "$@" > "$BREW_ARGS"\nif [[ "$1" == "info" ]]; then printf \'{"formulae":[]}\\n\'; fi\n');
                await chmod(join(dir, "brew"), 0o755);
                execFileSync("bash", ["-e", "-c", stepScript(step)], {env: {...process.env, PATH: `${dir}:${process.env.PATH}`, BREW_ARGS: args, GITHUB_OUTPUT: join(dir, "output"), TESTING_FORMULAE: formulae, FORMULAE: formulae}});
                const actual = (await readFile(args, "utf8")).trim().split("\n");
                assert.deepEqual(actual.slice(2), formulae.split(","));
            } finally {
                await rm(dir, {recursive: true, force: true});
            }
        });
    }
}
