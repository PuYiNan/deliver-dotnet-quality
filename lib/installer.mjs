import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

const skillName = 'deliver-dotnet-quality';

function timestamp(date = new Date()) {
  return date.toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);
}

async function exists(target) {
  try {
    await fs.lstat(target);
    return true;
  } catch (error) {
    if (error?.code === 'ENOENT') return false;
    throw error;
  }
}

async function listFiles(root) {
  const result = [];
  async function visit(directory) {
    const entries = await fs.readdir(directory, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (entry.isFile()) result.push(path.relative(root, absolute));
      else throw new Error(`Skill packages cannot contain links or special files: ${absolute}`);
    }
  }
  await visit(root);
  return result;
}

async function hashFile(file) {
  return crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');
}

export async function verifyTrees(source, destination) {
  const sourceFiles = await listFiles(source);
  const destinationFiles = await listFiles(destination);
  if (JSON.stringify(sourceFiles) !== JSON.stringify(destinationFiles)) {
    throw new Error('Installed Skill file list does not match the package.');
  }
  for (const relative of sourceFiles) {
    const [sourceHash, destinationHash] = await Promise.all([
      hashFile(path.join(source, relative)),
      hashFile(path.join(destination, relative)),
    ]);
    if (sourceHash !== destinationHash) {
      throw new Error(`Installed Skill hash mismatch: ${relative}`);
    }
  }
  return { files: sourceFiles.length };
}

function assertDirectChild(root, target) {
  if (path.dirname(target) !== root || path.basename(target) !== skillName) {
    throw new Error(`Unsafe Skill destination: ${target}`);
  }
}

export async function installSkill({ source, root, agent = 'custom', dryRun = false, now = new Date() }) {
  const resolvedSource = path.resolve(source);
  const resolvedRoot = path.resolve(root);
  const target = path.join(resolvedRoot, skillName);
  assertDirectChild(resolvedRoot, target);
  if (!(await exists(path.join(resolvedSource, 'SKILL.md')))) {
    throw new Error(`Packaged Skill is incomplete: ${resolvedSource}`);
  }

  if (dryRun) {
    return { agent, root: resolvedRoot, target, backup: null, dryRun: true };
  }

  await fs.mkdir(resolvedRoot, { recursive: true });
  let suffix = timestamp(now);
  let staging = path.join(resolvedRoot, `${skillName}.installing-${suffix}`);
  let backup = path.join(resolvedRoot, `${skillName}.backup-${suffix}`);
  let collision = 1;
  while (await exists(staging) || await exists(backup)) {
    suffix = `${timestamp(now)}-${collision++}`;
    staging = path.join(resolvedRoot, `${skillName}.installing-${suffix}`);
    backup = path.join(resolvedRoot, `${skillName}.backup-${suffix}`);
  }

  let verification;
  try {
    await fs.cp(resolvedSource, staging, { recursive: true, errorOnExist: true, force: false });
    verification = await verifyTrees(resolvedSource, staging);
  } catch (error) {
    if (await exists(staging)) await fs.rm(staging, { recursive: true, force: true });
    throw error;
  }
  const hadExisting = await exists(target);
  if (hadExisting) await fs.rename(target, backup);

  try {
    await fs.rename(staging, target);
  } catch (error) {
    if (hadExisting && !(await exists(target)) && await exists(backup)) {
      await fs.rename(backup, target);
    }
    throw error;
  }

  return {
    agent,
    root: resolvedRoot,
    target,
    backup: hadExisting ? backup : null,
    files: verification.files,
    dryRun: false,
  };
}

export async function restoreSkill({ root, backup }) {
  const resolvedRoot = path.resolve(root);
  const resolvedBackup = path.resolve(backup);
  const target = path.join(resolvedRoot, skillName);
  assertDirectChild(resolvedRoot, target);
  if (path.dirname(resolvedBackup) !== resolvedRoot || !path.basename(resolvedBackup).startsWith(`${skillName}.backup-`)) {
    throw new Error(`Backup must be a ${skillName}.backup-* directory directly inside ${resolvedRoot}.`);
  }
  if (!(await exists(resolvedBackup))) throw new Error(`Backup does not exist: ${resolvedBackup}`);

  let displaced = null;
  if (await exists(target)) {
    let suffix = timestamp();
    displaced = path.join(resolvedRoot, `${skillName}.replaced-${suffix}`);
    let collision = 1;
    while (await exists(displaced)) {
      suffix = `${timestamp()}-${collision++}`;
      displaced = path.join(resolvedRoot, `${skillName}.replaced-${suffix}`);
    }
    await fs.rename(target, displaced);
  }
  try {
    await fs.rename(resolvedBackup, target);
  } catch (error) {
    if (displaced && !(await exists(target))) await fs.rename(displaced, target);
    throw error;
  }
  return { root: resolvedRoot, target, restoredFrom: resolvedBackup, displaced };
}
