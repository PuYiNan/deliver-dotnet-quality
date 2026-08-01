import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const npmCli = process.env.npm_execpath;
if (!npmCli) throw new Error('npm_execpath is required; run this check through npm run test:package.');
function runNpm(arguments_, options = {}) {
  return execFileSync(process.execPath, [npmCli, ...arguments_], options);
}
let archive;
let temporary;
try {
  const packed = JSON.parse(runNpm(['pack', '--json'], { cwd: root, encoding: 'utf8', windowsHide: true }))[0];
  archive = path.join(root, packed.filename);
  const names = packed.files.map((item) => item.path);
  assert.ok(names.includes('bin/deliver-quality.mjs'));
  assert.ok(names.includes('skills/deliver-dotnet-quality/SKILL.md'));
  assert.ok(names.includes('skills/deliver-dotnet-quality/assets/repo-template/.ai-quality/adapters/node.ps1'));
  assert.ok(!names.some((name) => name.startsWith('tests/') || name.startsWith('.git/')));

  temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'deliver-quality-pack-'));
  await fs.writeFile(path.join(temporary, 'package.json'), '{"private":true}', 'utf8');
  runNpm(['install', '--ignore-scripts', '--no-audit', '--no-fund', archive], {
    cwd: temporary,
    encoding: 'utf8',
    windowsHide: true,
  });
  const installedCli = path.join(temporary, 'node_modules', 'deliver-code-quality', 'bin', 'deliver-quality.mjs');
  const help = spawnSync(process.execPath, [installedCli, '--help'], { cwd: temporary, encoding: 'utf8', windowsHide: true });
  assert.equal(help.status, 0, help.stderr);
  assert.match(help.stdout, /deliver-code-quality/);
  const npmBinHelp = runNpm(['exec', '--', 'deliver-code-quality', '--help'], {
    cwd: temporary,
    encoding: 'utf8',
    windowsHide: true,
  });
  assert.match(npmBinHelp, /deliver-code-quality/);

  const destination = path.join(temporary, 'agent-skills');
  const install = spawnSync(process.execPath, [installedCli, 'install-skill', '--agent', 'pi', '--destination', destination, '--json'], {
    cwd: temporary,
    encoding: 'utf8',
    windowsHide: true,
  });
  assert.equal(install.status, 0, install.stderr);
  assert.equal(JSON.parse(install.stdout).ok, true);
  assert.ok((await fs.stat(path.join(destination, 'deliver-dotnet-quality', 'SKILL.md'))).isFile());
  process.stdout.write(`Packed and installed ${packed.filename} with ${names.length} files.\n`);
} finally {
  if (archive) await fs.rm(archive, { force: true });
  if (temporary) await fs.rm(temporary, { recursive: true, force: true });
}
