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
