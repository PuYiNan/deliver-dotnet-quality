import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import fsPromises from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import readline from 'node:readline/promises';
import { fileURLToPath } from 'node:url';
import { installSkill, restoreSkill } from './installer.mjs';
import { resolveAgentSelection, resolveAgentSkillRoot, supportedAgents } from './paths.mjs';
import { findPowerShell, runPowerShell } from './powershell.mjs';

const packageRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const skillSource = path.join(packageRoot, 'skills', 'deliver-dotnet-quality');

function parseArguments(argv) {
  const command = argv[0]?.startsWith('-') ? 'help' : (argv.shift() ?? 'help');
  const options = {};
  const positional = [];
  while (argv.length > 0) {
    const token = argv.shift();
    if (token === '-h') { options.help = true; continue; }
    if (!token.startsWith('--')) { positional.push(token); continue; }
    const separator = token.indexOf('=');
    if (separator > 2) {
      options[token.slice(2, separator)] = token.slice(separator + 1);
      continue;
    }
    const name = token.slice(2);
    if (argv[0] && !argv[0].startsWith('-')) options[name] = argv.shift();
    else options[name] = true;
  }
  return { command, options, positional };
}

function assertOptions(options, allowed) {
  const unknown = Object.keys(options).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) throw new Error(`Unknown option(s): ${unknown.map((key) => `--${key}`).join(', ')}`);
}

function repositoryPath(positional, options) {
  return path.resolve(options.repository ?? positional[0] ?? process.cwd());
}

function adapterArguments(value) {
  if (!value) return [];
  const adapters = String(value).split(',').map((item) => item.trim()).filter(Boolean);
  const allowed = ['dotnet', 'node', 'python', 'command'];
  const invalid = adapters.filter((adapter) => !allowed.includes(adapter));
  if (invalid.length > 0) throw new Error(`Unsupported adapter(s): ${invalid.join(', ')}.`);
  return adapters;
}

function writeResult(result, json) {
  if (json) process.stdout.write(`${JSON.stringify({ ok: true, ...result }, null, 2)}\n`);
  else {
    if (result.message) process.stdout.write(`${result.message}\n`);
    if (result.stdout) process.stdout.write(`${result.stdout}\n`);
  }
}

function rootSelections(agent, destination) {
  if (destination) {
    if (!agent || agent === 'all' || String(agent).includes(',')) {
      throw new Error('--destination requires exactly one --agent.');
    }
    if (!supportedAgents.includes(agent)) throw new Error(`Unsupported agent '${agent}'.`);
    return [{ agent, root: path.resolve(destination) }];
  }
  return resolveAgentSelection(agent);
}

async function promptSetup(options) {
  if (options.agent) return options.agent;
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('Non-interactive setup requires --agent pi|codex|claude|agents|all.');
  }
  const terminal = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    const answer = (await terminal.question('Install the Skill for pi, codex, claude, agents, or all? [pi] ')).trim();
    return answer || 'pi';
  } finally {
    terminal.close();
  }
}

async function confirmSetup(plan, yes) {
  if (yes) return;
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('Non-interactive setup requires --yes.');
  }
  process.stdout.write(`${plan}\n`);
  const terminal = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    const answer = (await terminal.question('Continue? [y/N] ')).trim().toLowerCase();
    if (!['y', 'yes'].includes(answer)) throw new Error('Setup cancelled.');
  } finally {
    terminal.close();
  }
}

function workflowScript(name) {
  return path.join(skillSource, 'scripts', name);
}

function runInit(repository, options) {
  const parameters = ['-RepositoryPath', repository];
  const adapters = adapterArguments(options.adapters);
  if (adapters.length > 0) parameters.push('-Adapters', adapters.join(','));
  if (options.force) parameters.push('-Force');
  if (options.preflight) parameters.push('-Preflight');
  return runPowerShell(workflowScript('bootstrap-repository.ps1'), parameters, { cwd: repository });
}

function runUpgrade(repository, options) {
  const parameters = ['-RepositoryPath', repository];
  if (options['include-agent-instructions']) parameters.push('-IncludeAgentInstructions');
  if (options.rollback) parameters.push('-Rollback', String(options.rollback));
  if (options.preflight) parameters.push('-Preflight');
  return runPowerShell(workflowScript('upgrade-repository.ps1'), parameters, { cwd: repository });
}

function commandVersion(command, args = ['--version']) {
  const result = spawnSync(command, args, { encoding: 'utf8', windowsHide: true });
  return {
    available: !result.error && result.status === 0,
    version: result.status === 0 ? (result.stdout || result.stderr).trim().split(/\r?\n/)[0] : null,
  };
}

function npmVersion() {
  if (process.env.npm_execpath) return commandVersion(process.execPath, [process.env.npm_execpath, '--version']);
  if (process.platform === 'win32') {
    return commandVersion(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'npm --version']);
  }
  return commandVersion('npm');
}

async function getVersion() {
  return JSON.parse(await fsPromises.readFile(path.join(packageRoot, 'package.json'), 'utf8')).version;
}

const help = `deliver-code-quality - install evidence-based delivery controls for AI coding agents

Usage:
  npx deliver-code-quality setup --agent pi --repository . --yes
  npx deliver-code-quality install-skill --agent pi|codex|claude|agents|all
  npx deliver-code-quality init [repository] [--adapters dotnet,node,python,command]
  npx deliver-code-quality upgrade [repository] [--include-agent-instructions]
  npx deliver-code-quality upgrade [repository] --rollback <backup-id>
  npx deliver-code-quality restore-skill --agent <agent> --backup <path>
  npx deliver-code-quality doctor [--json]

Options:
  --destination <path>  Override one agent's global skills root.
  --dry-run             Resolve installation paths without writing files.
  --json                Emit machine-readable output for AI agents.
  --yes                 Confirm non-interactive setup.
  --help                Show command help.
  --version             Show package version.

setup installs the global Skill, then bootstraps a new repository or upgrades an existing one.
PowerShell 7 (pwsh) is required for repository initialization and quality gates.`;

export async function main(rawArguments) {
  const parsed = parseArguments([...rawArguments]);
  const { command, options, positional } = parsed;
  if (options.version || command === 'version') {
    process.stdout.write(`${await getVersion()}\n`);
    return;
  }
  if (options.help || command === 'help') {
    process.stdout.write(`${help}\n`);
    return;
  }

  if (command === 'doctor') {
    assertOptions(options, ['json']);
    const shell = findPowerShell();
    const agentPaths = Object.fromEntries(supportedAgents.map((agent) => {
      const root = resolveAgentSkillRoot(agent);
      return [agent, { root, installed: fs.existsSync(path.join(root, 'deliver-dotnet-quality', 'SKILL.md')) }];
    }));
    const result = {
      healthy: shell.available,
      node: process.version,
      npm: npmVersion(),
      powershell: shell,
      platform: process.platform,
      packageVersion: await getVersion(),
      agentPaths,
    };
    writeResult({ ...result, message: shell.available ? 'Environment is ready.' : 'Install PowerShell 7 before initializing repositories.' }, options.json);
    if (!shell.available) process.exitCode = 1;
    return;
  }

  if (command === 'install-skill') {
    assertOptions(options, ['agent', 'destination', 'dry-run', 'json']);
    const selections = rootSelections(options.agent, options.destination);
    const installations = [];
    for (const selection of selections) {
      installations.push(await installSkill({ source: skillSource, ...selection, dryRun: Boolean(options['dry-run']) }));
    }
    writeResult({ installations, message: `Installed Skill for ${installations.map((item) => item.agent).join(', ')}.` }, options.json);
    return;
  }

  if (command === 'restore-skill') {
    assertOptions(options, ['agent', 'destination', 'backup', 'json']);
    if (!options.backup) throw new Error('restore-skill requires --backup <path>.');
    const selections = rootSelections(options.agent, options.destination);
    if (selections.length !== 1) throw new Error('restore-skill supports exactly one agent at a time.');
    const restored = await restoreSkill({ root: selections[0].root, backup: options.backup });
    writeResult({ restored, message: `Restored Skill from ${restored.restoredFrom}.` }, options.json);
    return;
  }

  if (command === 'init') {
    assertOptions(options, ['repository', 'adapters', 'force', 'json']);
    const repository = repositoryPath(positional, options);
    const result = runInit(repository, options);
    writeResult({ repository, operation: 'init', ...result, message: `Initialized ${repository}.` }, options.json);
    return;
  }

  if (command === 'upgrade') {
    assertOptions(options, ['repository', 'include-agent-instructions', 'rollback', 'json']);
    const repository = repositoryPath(positional, options);
    const result = runUpgrade(repository, options);
    writeResult({ repository, operation: options.rollback ? 'rollback' : 'upgrade', ...result, message: `${options.rollback ? 'Rolled back' : 'Upgraded'} ${repository}.` }, options.json);
    return;
  }

  if (command === 'setup') {
    assertOptions(options, ['agent', 'destination', 'repository', 'adapters', 'force', 'include-agent-instructions', 'yes', 'json']);
    const agent = await promptSetup(options);
    const repository = repositoryPath(positional, options);
    const selections = rootSelections(agent, options.destination);
    const operation = fs.existsSync(path.join(repository, '.ai-quality', 'config.json')) ? 'upgrade' : 'init';
    const plan = `Agent(s): ${selections.map((item) => item.agent).join(', ')}\nRepository: ${repository}\nOperation: ${operation}`;
    await confirmSetup(plan, Boolean(options.yes));
    if (operation === 'upgrade') runUpgrade(repository, { ...options, preflight: true });
    else runInit(repository, { ...options, preflight: true });
    const installations = [];
    for (const selection of selections) installations.push(await installSkill({ source: skillSource, ...selection }));
    const workflow = operation === 'upgrade' ? runUpgrade(repository, options) : runInit(repository, options);
    writeResult({ installations, repository, operation, workflow, message: `Setup completed for ${repository}. Restart or reload the selected agent.` }, options.json);
    return;
  }

  throw new Error(`Unknown command '${command}'. Run deliver-code-quality --help.`);
}
