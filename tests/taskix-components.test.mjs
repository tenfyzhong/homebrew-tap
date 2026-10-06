import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const name = "taskix";
const formula = await readFile(new URL(`../Formula/${name}.rb`, import.meta.url), "utf8");
const env = { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_DEVELOPER: "1" };
const skip = spawnSync("brew", ["--version"], { encoding: "utf8" }).status !== 0;

for (const regenerate of [false, true]) {
    test(`${name}_component_order_${regenerate ? "after_bottle_regeneration" : "current"}`, { skip, timeout: 180_000 }, async t => {
        const directory = await mkdtemp(join(tmpdir(), `${name}-components-`));
        t.after(() => rm(directory, { recursive: true, force: true }));
        await mkdir(join(directory, "Formula"));
        const path = join(directory, "Formula", `${name}.rb`);
        await writeFile(path, formula);
        if (regenerate) {
            const result = spawnSync("brew", ["ruby", "-e", `
require "utils/ast"
path = ARGV.fetch(0)
source = File.read(path)
block = source[/^  bottle do\n.*?^  end\n/m]
raise "Expected a bottle block" unless block
ast = Utils::AST::FormulaAST.new(source)
ast.remove_stanza(:bottle, type: :block_call)
ast = Utils::AST::FormulaAST.new(ast.process)
ast.add_bottle_block(block)
File.write(path, ast.process)
`, path], { encoding: "utf8", env, timeout: 120_000 });
            assert.equal(result.status, 0, result.stdout + result.stderr);
        }
        const result = spawnSync("brew", ["style", "--only-cops", "FormulaAudit/ComponentsOrder", path], {
            encoding: "utf8", env, timeout: 120_000,
        });
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.match(result.stdout, /1 file inspected/);
    });
}

test("taskix_service_uses_top_level_serve_and_documents_reload", () => {
    assert.match(formula, /run \[opt_bin\/"taskix", "serve"\]/);
    assert.match(formula, /taskix reload/);
});

for (const [spec, version, args] of [
    ["stable", "0.5.0", ["memory", "serve"]],
    ["stable", "0.5.1", ["serve"]],
    ["head", "", ["serve"]],
]) {
    test(`taskix_service_command_${spec}_${version}`, { skip }, () => {
        const result = spawnSync("brew", ["ruby", "-e", `
require "formulary"
require "json"
f = Formulary.factory(ARGV.fetch(0), ARGV.fetch(1).to_sym)
f.stable.version(ARGV.fetch(2)) unless ARGV.fetch(2).empty?
puts JSON.generate(f.service.command)
`, new URL("../Formula/taskix.rb", import.meta.url).pathname, spec, version], {
            encoding: "utf8", env, timeout: 120_000,
        });
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.deepEqual(JSON.parse(result.stdout).slice(1), args);
    });
}

test("taskix_local_service_uses_top_level_serve", { skip }, async t => {
    const directory = await mkdtemp(join(tmpdir(), "taskix-service-local-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    for (const path of ["Formula", "lib", "share/taskix"]) {
        await mkdir(join(directory, path), { recursive: true });
    }
    const path = join(directory, "Formula/taskix.rb");
    await writeFile(path, formula);
    await writeFile(join(directory, "lib/agentix_local_build.rb"),
        await readFile(new URL("../lib/agentix_local_build.rb", import.meta.url)));
    await writeFile(join(directory, "share/taskix/agentix-local.json"), JSON.stringify({
        url: "file:///tmp/taskix-service-fixture.tar.gz",
        version: "0.0.0-local.abcdef.debug",
        sha256: "a".repeat(64),
        profile: "debug",
    }));
    const result = spawnSync("brew", ["ruby", "-e", `
require "formulary"
require "json"
f = Formulary.factory(ARGV.fetch(0), :stable)
puts JSON.generate(f.service.command)
`, path], { encoding: "utf8", env, timeout: 120_000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(JSON.parse(result.stdout).slice(1), ["serve"]);
});
