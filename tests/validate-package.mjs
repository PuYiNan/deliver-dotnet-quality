import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseDocument } from 'yaml';

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const versionText = fs.readFileSync(path.join(root, 'VERSION'), 'utf8');
const version = versionText.match(/\b\d+\.\d+\.\d+\b/)?.[0];
assert.equal(packageJson.name, 'deliver-code-quality');
assert.equal(packageJson.version, version, 'package.json and VERSION must match');
assert.equal(packageJson.license, 'MIT');
assert.equal(packageJson.private, undefined);
assert.equal(packageJson.publishConfig.access, 'public');
assert.equal(packageJson.publishConfig.registry, 'https://registry.npmjs.org/');
assert.equal(packageJson.repository.url, 'git+https://github.com/PuYiNan/deliver-code-quality.git');
assert.ok(fs.existsSync(path.join(root, 'LICENSE')));

const skillRoot = path.join(root, 'skills', 'deliver-dotnet-quality');
const skill = fs.readFileSync(path.join(skillRoot, 'SKILL.md'), 'utf8');
assert.match(skill, /^---\nname: deliver-dotnet-quality\ndescription: .+\n---/s);
for (const relative of [
  'agents/openai.yaml',
  'scripts/bootstrap-repository.ps1',
  'scripts/upgrade-repository.ps1',
  'assets/repo-template/.ai-quality/adapters/dotnet.ps1',
  'assets/repo-template/.ai-quality/adapters/node.ps1',
  'assets/repo-template/.ai-quality/adapters/python.ps1',
  'assets/repo-template/.ai-quality/adapters/command.ps1',
]) {
  assert.ok(fs.existsSync(path.join(skillRoot, relative)), `missing Skill resource: ${relative}`);
}

for (const file of ['package.json', 'release-please-config.json', '.release-please-manifest.json']) {
  JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
}

const sensitivePath = /C:\\Users\\LiJia|D:\\LXCODE\\PIAgent\\deliver-dotnet-quality/i;
function inspect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) inspect(absolute);
    else if (/\.(md|json|mjs|ps1|yaml|yml|ts)$/.test(entry.name)) {
      assert.doesNotMatch(fs.readFileSync(absolute, 'utf8'), sensitivePath, `local machine path leaked in ${absolute}`);
    }
  }
}
inspect(root);

function validateYaml(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) validateYaml(absolute);
    else if (/\.ya?ml$/.test(entry.name)) {
      const document = parseDocument(fs.readFileSync(absolute, 'utf8'), { uniqueKeys: true });
      assert.equal(document.errors.length, 0, `invalid YAML in ${absolute}: ${document.errors.join('; ')}`);
    }
  }
}
validateYaml(path.join(root, '.github'));
validateYaml(path.join(root, 'skills'));
process.stdout.write('Package metadata, Skill structure, versions, YAML, and path hygiene passed.\n');
