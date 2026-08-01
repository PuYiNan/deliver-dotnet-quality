import assert from 'node:assert/strict';
import fs from 'node:fs';

const expectedVersion = process.argv[2];
const tag = process.argv[3];
if (!expectedVersion || !tag) throw new Error('Usage: node tests/assert-release-version.mjs <version> <tag>');
const packageVersion = JSON.parse(fs.readFileSync('package.json', 'utf8')).version;
const versionFile = fs.readFileSync('VERSION', 'utf8').match(/\b\d+\.\d+\.\d+\b/)?.[0];
assert.equal(packageVersion, expectedVersion, 'package.json does not match the release version');
assert.equal(versionFile, expectedVersion, 'VERSION does not match the release version');
assert.equal(tag, `v${expectedVersion}`, 'Git tag does not match the release version');
process.stdout.write(`Release version ${expectedVersion} is consistent.\n`);
