import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { installSkill, legacySkillNames, restoreSkill, skillName, verifyTrees } from '../lib/installer.mjs';
import { resolveAgentSelection, resolveAgentSkillRoot } from '../lib/paths.mjs';

const repositoryRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const skillSource = path.join(repositoryRoot, 'skills', skillName);
const legacySkillName = legacySkillNames[0];
const cli = path.join(repositoryRoot, 'bin', 'deliver-quality.mjs');
const expectedVersion = JSON.parse(await fs.readFile(path.join(repositoryRoot, 'package.json'), 'utf8')).version;

async function temporaryDirectory(name) {
  return fs.mkdtemp(path.join(os.tmpdir(), `${name}-`));
}

function runCli(arguments_, cwd = repositoryRoot) {
  const result = spawnSync(process.execPath, [cli, ...arguments_], { cwd, encoding: 'utf8', windowsHide: true });
  if (result.status !== 0) {
    throw new Error(`CLI failed (${result.status}):\n${result.stderr}\n${result.stdout}`);
  }
  return result;
}

test('resolves Pi, Codex, Claude, and portable Agent Skills roots', () => {
  const home = path.resolve('test-home');
  assert.equal(resolveAgentSkillRoot('pi', { home, env: {} }), path.join(home, '.pi', 'agent', 'skills'));
  assert.equal(resolveAgentSkillRoot('codex', { home, env: {} }), path.join(home, '.codex', 'skills'));
  assert.equal(resolveAgentSkillRoot('claude', { home, env: {} }), path.join(home, '.claude', 'skills'));
  assert.equal(resolveAgentSkillRoot('agents', { home, env: {} }), path.join(home, '.agents', 'skills'));
  assert.equal(resolveAgentSkillRoot('codex', { home, env: { CODEX_HOME: path.join(home, 'custom-codex') } }), path.join(home, 'custom-codex', 'skills'));
  assert.deepEqual(resolveAgentSelection('pi,pi,codex', { home, env: {} }).map((item) => item.agent), ['pi', 'codex']);
});

test('installs atomically, backs up an existing Skill, and restores it', async (context) => {
  const root = await temporaryDirectory('deliver-quality-install');
  context.after(() => fs.rm(root, { recursive: true, force: true }));

  const first = await installSkill({ source: skillSource, root, agent: 'test', now: new Date('2026-08-01T00:00:00Z') });
  assert.equal(first.backup, null);
  assert.ok(first.files > 0);
  await verifyTrees(skillSource, first.target);

  await fs.writeFile(path.join(first.target, 'local-marker.txt'), 'old installation', 'utf8');
  const second = await installSkill({ source: skillSource, root, agent: 'test', now: new Date('2026-08-01T00:00:01Z') });
  assert.ok(second.backup);
  assert.equal(await fs.readFile(path.join(second.backup, 'local-marker.txt'), 'utf8'), 'old installation');
  await verifyTrees(skillSource, second.target);

  const restored = await restoreSkill({ root, backup: second.backup });
  assert.equal(await fs.readFile(path.join(restored.target, 'local-marker.txt'), 'utf8'), 'old installation');
  assert.equal(restored.displaced.length, 1);
});

test('migrates a legacy Skill without leaving two active identifiers and can roll back', async (context) => {
  const base = await temporaryDirectory('deliver-quality-migrate');
  context.after(() => fs.rm(base, { recursive: true, force: true }));
  const root = path.join(base, 'skills');
  await fs.mkdir(root);
  const legacyTarget = path.join(root, legacySkillName);
  await fs.mkdir(legacyTarget, { recursive: true });
  await fs.writeFile(path.join(legacyTarget, 'SKILL.md'), `---\nname: ${legacySkillName}\ndescription: legacy\n---\n`, 'utf8');
  await fs.writeFile(path.join(legacyTarget, 'local-marker.txt'), 'legacy installation', 'utf8');

  const installed = await installSkill({ source: skillSource, root, agent: 'test', now: new Date('2026-08-02T00:00:00Z') });
  assert.equal(installed.migrations.length, 1);
  assert.equal(installed.migrations[0].skill, legacySkillName);
  assert.equal(path.dirname(installed.migrations[0].backup), path.join(path.dirname(root), 'skill-backups'));
  await assert.rejects(fs.stat(legacyTarget), { code: 'ENOENT' });
  await verifyTrees(skillSource, path.join(root, skillName));

  const restored = await restoreSkill({ root, backup: installed.migrations[0].backup });
  assert.equal(restored.restoredSkillName, legacySkillName);
  assert.equal(await fs.readFile(path.join(legacyTarget, 'local-marker.txt'), 'utf8'), 'legacy installation');
  await assert.rejects(fs.stat(path.join(root, skillName)), { code: 'ENOENT' });
});

test('packaged CLI reports help, version, and JSON doctor output', () => {
  assert.match(runCli(['--help']).stdout, /setup --agent pi/);
  assert.equal(runCli(['--version']).stdout.trim(), expectedVersion);
  const doctor = JSON.parse(runCli(['doctor', '--json']).stdout);
  assert.equal(doctor.ok, true);
  assert.equal(doctor.packageVersion, expectedVersion);
  assert.equal(doctor.npm.available, true);
  assert.equal(doctor.powershell.available, true);
  assert.deepEqual(Object.keys(doctor.agentPaths), ['pi', 'codex', 'claude', 'agents']);
});

test('CLI initializes a detected Node repository and upgrades it without replacing config', async (context) => {
  const root = await temporaryDirectory('deliver-quality-init');
  context.after(() => fs.rm(root, { recursive: true, force: true }));
  const product = path.join(root, 'product');
  await fs.mkdir(product);
  await fs.writeFile(path.join(product, 'package.json'), JSON.stringify({ name: 'fixture', scripts: { test: 'node --test' } }, null, 2), 'utf8');

  const initialized = JSON.parse(runCli(['init', product, '--adapters', 'node,python', '--json']).stdout);
  assert.equal(initialized.operation, 'init');
  const configPath = path.join(product, '.ai-quality', 'config.json');
  const configBefore = await fs.readFile(configPath, 'utf8');
  const config = JSON.parse(configBefore);
  assert.deepEqual(config.gate.adapters.map((adapter) => adapter.type), ['node', 'python']);

  const upgraded = JSON.parse(runCli(['upgrade', product, '--include-agent-instructions', '--json']).stdout);
  assert.equal(upgraded.operation, 'upgrade');
  assert.equal(await fs.readFile(configPath, 'utf8'), configBefore);
  assert.match(upgraded.stdout, /Rollback:/);
});

test('setup installs the selected global Skill and initializes a repository non-interactively', async (context) => {
  const root = await temporaryDirectory('deliver-quality-setup');
  context.after(() => fs.rm(root, { recursive: true, force: true }));
  const skillsRoot = path.join(root, 'skills');
  const product = path.join(root, 'product');
  await fs.mkdir(product);
  await fs.writeFile(path.join(product, 'requirements.txt'), '', 'utf8');
  await fs.mkdir(path.join(product, 'tests'));
  await fs.writeFile(path.join(product, 'tests', 'test_smoke.py'), 'import unittest\n\nclass Smoke(unittest.TestCase):\n    def test_ok(self):\n        self.assertTrue(True)\n', 'utf8');

  const result = JSON.parse(runCli([
    'setup', '--agent', 'pi', '--destination', skillsRoot,
    '--repository', product, '--yes', '--json',
  ]).stdout);
  assert.equal(result.operation, 'init');
  assert.equal(result.installations[0].agent, 'pi');
  await verifyTrees(skillSource, path.join(skillsRoot, skillName));
  assert.equal(JSON.parse(await fs.readFile(path.join(product, '.ai-quality', 'config.json'), 'utf8')).gate.adapters[0].type, 'python');
});

test('setup preflight leaves the global Skill untouched when repository bootstrap is invalid', async (context) => {
  const root = await temporaryDirectory('deliver-quality-preflight');
  context.after(() => fs.rm(root, { recursive: true, force: true }));
  const skillsRoot = path.join(root, 'skills');
  const invalidRepository = path.join(root, 'empty');
  await fs.mkdir(invalidRepository);

  const result = spawnSync(process.execPath, [
    cli, 'setup', '--agent', 'pi', '--destination', skillsRoot,
    '--repository', invalidRepository, '--yes', '--json',
  ], { cwd: repositoryRoot, encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 1);
  assert.match(JSON.parse(result.stderr).error, /does not look like a source repository/);
  await assert.rejects(fs.stat(path.join(skillsRoot, skillName)), { code: 'ENOENT' });
  await assert.rejects(fs.stat(path.join(skillsRoot, legacySkillName)), { code: 'ENOENT' });
});
