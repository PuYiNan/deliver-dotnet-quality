import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

export const skillName = 'deliver-code-quality';
export const legacySkillNames = Object.freeze(['deliver-dotnet-quality']);

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

function assertDirectChild(root, target, expectedName = skillName) {
  if (path.dirname(target) !== root || path.basename(target) !== expectedName) {
    throw new Error(`Unsafe Skill destination: ${target}`);
  }
}

function backupRootFor(root) {
  return path.join(path.dirname(root), 'skill-backups');
}

async function uniquePath(directory, name, kind, now) {
  let suffix = timestamp(now);
  let candidate = path.join(directory, `${name}.${kind}-${suffix}`);
  let collision = 1;
  while (await exists(candidate)) {
    suffix = `${timestamp(now)}-${collision++}`;
    candidate = path.join(directory, `${name}.${kind}-${suffix}`);
  }
  return candidate;
}

export async function installSkill({ source, root, agent = 'custom', dryRun = false, now = new Date() }) {
  const resolvedSource = path.resolve(source);
  const resolvedRoot = path.resolve(root);
  const target = path.join(resolvedRoot, skillName);
  assertDirectChild(resolvedRoot, target);
  const legacyTargets = legacySkillNames.map((name) => ({ name, target: path.join(resolvedRoot, name) }));
  for (const legacy of legacyTargets) assertDirectChild(resolvedRoot, legacy.target, legacy.name);
  if (!(await exists(path.join(resolvedSource, 'SKILL.md')))) {
    throw new Error(`Packaged Skill is incomplete: ${resolvedSource}`);
  }

  if (dryRun) {
    const legacyActive = [];
    for (const legacy of legacyTargets) if (await exists(legacy.target)) legacyActive.push(legacy.target);
    return { agent, root: resolvedRoot, target, backup: null, legacyActive, dryRun: true };
  }

  await fs.mkdir(resolvedRoot, { recursive: true });
  const backupRoot = backupRootFor(resolvedRoot);
  await fs.mkdir(backupRoot, { recursive: true });
  const staging = await uniquePath(resolvedRoot, skillName, 'installing', now);

  let verification;
  try {
    await fs.cp(resolvedSource, staging, { recursive: true, errorOnExist: true, force: false });
    verification = await verifyTrees(resolvedSource, staging);
  } catch (error) {
    if (await exists(staging)) await fs.rm(staging, { recursive: true, force: true });
    throw error;
  }
  const displaced = [];
  try {
    for (const active of [{ name: skillName, target }, ...legacyTargets]) {
      if (!(await exists(active.target))) continue;
      const backup = await uniquePath(backupRoot, active.name, 'backup', now);
      await fs.rename(active.target, backup);
      displaced.push({ ...active, backup });
    }
    await fs.rename(staging, target);
  } catch (error) {
    if (await exists(staging)) await fs.rm(staging, { recursive: true, force: true });
    for (const entry of [...displaced].reverse()) {
      if (!(await exists(entry.target)) && await exists(entry.backup)) {
        await fs.rename(entry.backup, entry.target);
      }
    }
    throw error;
  }

  const canonicalBackup = displaced.find((entry) => entry.name === skillName)?.backup ?? null;
  const migrations = displaced
    .filter((entry) => legacySkillNames.includes(entry.name))
    .map((entry) => ({ skill: entry.name, from: entry.target, backup: entry.backup }));

  return {
    agent,
    root: resolvedRoot,
    target,
    backup: canonicalBackup,
    migrations,
    files: verification.files,
    dryRun: false,
  };
}

export async function restoreSkill({ root, backup }) {
  const resolvedRoot = path.resolve(root);
  const resolvedBackup = path.resolve(backup);
  const backupRoot = backupRootFor(resolvedRoot);
  const backupName = path.basename(resolvedBackup);
  const restoredSkillName = [skillName, ...legacySkillNames]
    .find((name) => backupName.startsWith(`${name}.backup-`));
  const acceptedParent = [resolvedRoot, backupRoot].includes(path.dirname(resolvedBackup));
  if (!acceptedParent || !restoredSkillName) {
    throw new Error(`Backup must be a recognized *.backup-* directory inside ${backupRoot} or ${resolvedRoot}.`);
  }
  if (!(await exists(resolvedBackup))) throw new Error(`Backup does not exist: ${resolvedBackup}`);
  await fs.mkdir(backupRoot, { recursive: true });

  const target = path.join(resolvedRoot, restoredSkillName);
  assertDirectChild(resolvedRoot, target, restoredSkillName);
  const activeNames = restoredSkillName === skillName ? [skillName] : [skillName, restoredSkillName];
  const displaced = [];
  try {
    for (const activeName of activeNames) {
      const activeTarget = path.join(resolvedRoot, activeName);
      if (!(await exists(activeTarget))) continue;
      const replacement = await uniquePath(backupRoot, activeName, 'replaced', new Date());
      await fs.rename(activeTarget, replacement);
      displaced.push({ target: activeTarget, replacement });
    }
    await fs.rename(resolvedBackup, target);
  } catch (error) {
    for (const entry of [...displaced].reverse()) {
      if (!(await exists(entry.target)) && await exists(entry.replacement)) {
        await fs.rename(entry.replacement, entry.target);
      }
    }
    throw error;
  }
  return {
    root: resolvedRoot,
    target,
    restoredSkillName,
    restoredFrom: resolvedBackup,
    displaced: displaced.map((entry) => entry.replacement),
  };
}
