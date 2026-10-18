import assert from "node:assert/strict";
import { test } from "node:test";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const workflow = await readFile(new URL("../.github/workflows/tests.yml", import.meta.url), "utf8");

function stepScript(name) {
    const step = workflow.split(`      - name: ${name}\n`)[1].split("\n      - ")[0];
    const inline = step.match(/        run: ([^|\n].*)/);
    return inline ? inline[1] : step.split("        run: |\n")[1].replace(/^          /gm, "");
}

for (const installFails of [false, true]) {
    test(`CI prepares style gems before parallel tests (install fails: ${installFails})`, async t => {
        const dir = await mkdtemp(join(tmpdir(), "tap-gem-setup-"));
        t.after(() => rm(dir, { recursive: true, force: true }));
        await writeFile(join(dir, "brew"), `#!/bin/bash
if [[ "$1" == "--repository" ]]; then
    echo "$TEST_DIR"
elif [[ "$*" == "install-bundler-gems --groups=style" ]]; then
    echo install >> "$TEST_DIR/events"
    exit "$INSTALL_STATUS"
else
    exit 90
fi
`);
        await writeFile(join(dir, "node"), '#!/bin/bash\necho test >> "$TEST_DIR/events"\n');
        await chmod(join(dir, "brew"), 0o755);
        await chmod(join(dir, "node"), 0o755);
        const result = spawnSync("bash", ["-e", "-c", stepScript("Test local source support")], {
            env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, TEST_DIR: dir, INSTALL_STATUS: installFails ? "42" : "0" },
            encoding: "utf8",
        });
        assert.equal(result.status, installFails ? 42 : 0, result.stderr);
        assert.equal(await readFile(join(dir, "events"), "utf8"), installFails ? "install\n" : "install\ntest\n");
    });
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
