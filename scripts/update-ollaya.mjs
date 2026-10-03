import { createHash } from "node:crypto";
import { appendFile, readFile, rename, rm, writeFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";

const repository = "ollaya-dev/ollaya";
const assets = ["ollaya-darwin-arm64.tar.zst", "ollaya-darwin-arm64-mlx.tar.zst",
    "ollaya-linux-amd64.tar.zst", "ollaya-linux-arm64.tar.zst"];
const releaseBase = `https://github.com/${repository}/releases/download/`;

function normalizeVersion(value) {
    const version = value.replace(/^v/, "");
    if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version)) {
        throw new Error(`Invalid version: ${value}; expected a stable X.Y.Z or vX.Y.Z`);
    }
    return version;
}

async function requestGithub(url) {
    console.log(`Fetching ${url}`);
    const headers = { "User-Agent": "homebrew-tap-ollaya-updater" };
    if (url.startsWith("https://api.github.com/")) {
        headers.Accept = "application/vnd.github+json";
        headers["X-GitHub-Api-Version"] = "2026-03-10";
        if (process.env.GH_TOKEN) headers.Authorization = `Bearer ${process.env.GH_TOKEN}`;
    }
    return fetch(url, { headers, signal: AbortSignal.timeout(300_000) });
}

async function checkedResponse(request, url) {
    const response = await request(url);
    if (!response.ok) throw new Error(`Download failed (${response.status}): ${url}`);
    return response;
}

export async function prepareUpdate(formula, { version: input = "", request = requestGithub } = {}) {
    const requested = input.trim() ? normalizeVersion(input.trim()) : null;
    const endpoint = requested ? `tags/v${requested}` : "latest";
    const release = await (await checkedResponse(request,
        `https://api.github.com/repos/${repository}/releases/${endpoint}`)).json();
    if (release.draft || release.prerelease) throw new Error("Expected a published stable release");
    const version = normalizeVersion(release.tag_name);
    if (requested && version !== requested) throw new Error("Release tag does not match requested version");
    const current = formula.match(/\/releases\/download\/v([^/]+)\//)?.[1];
    if (!current) throw new Error("Unexpected Formula archive layout");
    const oldParts = normalizeVersion(current).split(".").map(BigInt);
    const newParts = version.split(".").map(BigInt);
    for (let i = 0; i < 3; i++) {
        if (newParts[i] < oldParts[i]) throw new Error(`Refusing downgrade from ${current} to ${version}`);
        if (newParts[i] > oldParts[i]) break;
    }

    const tagBase = `${releaseBase}v${version}/`;
    const releaseAsset = name => {
        const matches = release.assets.filter(asset => asset.name === name);
        if (matches.length !== 1) throw new Error(`Missing release asset (or duplicate): ${name}`);
        if (matches[0].browser_download_url !== tagBase + name) throw new Error(`Unexpected asset URL: ${name}`);
        return matches[0].browser_download_url;
    };
    const manifest = await (await checkedResponse(request, releaseAsset("sha256sum.txt"))).text();
    const checksums = new Map();
    for (const line of manifest.trim().split(/\r?\n/)) {
        const entry = line.match(/^([a-f0-9]{64})\s+\*?(\S+)$/);
        if (!entry) throw new Error("Invalid checksum manifest");
        if (checksums.has(entry[2])) throw new Error(`Duplicate checksum: ${entry[2]}`);
        checksums.set(entry[2], entry[1]);
    }

    // Validate every platform before changing the Formula, including MLX's separate pack.
    for (const name of assets) {
        const url = releaseAsset(name);
        const expected = checksums.get(name);
        if (!expected) throw new Error(`Missing checksum: ${name}`);
        const response = await checkedResponse(request, url);
        const hash = createHash("sha256");
        for await (const chunk of response.body) hash.update(chunk);
        if (hash.digest("hex") !== expected) throw new Error(`Checksum mismatch: ${name}`);
    }

    let count = 0;
    const seen = new Set();
    let updated = formula.replace(/(\s+url ")https:\/\/github\.com\/ollaya-dev\/ollaya\/releases\/download\/v([^/]+)\/([^"\n]+)("\n\s+sha256 ")[a-f0-9]{64}("\n)/g,
        (match, prefix, oldVersion, name, middle, suffix) => {
            if (oldVersion !== current || !assets.includes(name) || seen.has(name)) {
                throw new Error("Unexpected Formula archive layout");
            }
            seen.add(name);
            count++;
            return `${prefix}${tagBase}${name}${middle}${checksums.get(name)}${suffix}`;
        });
    if (count !== assets.length) throw new Error("Unexpected Formula archive layout");
    return { formula: updated, version, changed: updated !== formula };
}

export async function updateFile(path, options) {
    const result = await prepareUpdate(await readFile(path, "utf8"), options);
    if (result.changed) {
        const temporary = `${path}.${process.pid}.tmp`;
        try {
            await writeFile(temporary, result.formula, { flag: "wx" });
            await rename(temporary, path);
        } finally {
            await rm(temporary, { force: true });
        }
    }
    return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    try {
        const result = await updateFile(fileURLToPath(new URL("../Formula/ollaya.rb", import.meta.url)),
            { version: process.env.OLLAYA_VERSION || "" });
        console.log(`${result.changed ? "Updated" : "Already current:"} Ollaya ${result.version}`);
        if (process.env.GITHUB_OUTPUT) {
            await appendFile(process.env.GITHUB_OUTPUT, `version=${result.version}\nchanged=${result.changed}\n`);
        }
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
