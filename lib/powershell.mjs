import { spawnSync } from 'node:child_process';

export function findPowerShell() {
  const result = spawnSync('pwsh', ['--version'], { encoding: 'utf8', windowsHide: true });
  return {
    available: !result.error && result.status === 0,
    version: result.status === 0 ? result.stdout.trim() : null,
    error: result.error?.message ?? ((result.stderr || '').trim() || null),
  };
}

export function runPowerShell(script, parameters = [], options = {}) {
  const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', script, ...parameters], {
    cwd: options.cwd,
    encoding: 'utf8',
    windowsHide: true,
  });
  if (result.error) throw new Error(`Unable to start PowerShell: ${result.error.message}`);
  if (result.status !== 0) {
    const details = [result.stderr, result.stdout].map((value) => value?.trim()).filter(Boolean).join('\n');
    throw new Error(`PowerShell workflow failed with exit code ${result.status}.${details ? `\n${details}` : ''}`);
  }
  return { exitCode: result.status, stdout: result.stdout.trim(), stderr: result.stderr.trim() };
}
