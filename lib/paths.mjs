import os from 'node:os';
import path from 'node:path';

export const supportedAgents = Object.freeze(['pi', 'codex', 'claude', 'agents']);

export function resolveAgentSkillRoot(agent, options = {}) {
  const env = options.env ?? process.env;
  const home = path.resolve(options.home ?? os.homedir());

  switch (agent) {
    case 'pi':
      return path.resolve(env.PI_AGENT_HOME ?? path.join(home, '.pi', 'agent'), 'skills');
    case 'codex':
      return path.resolve(env.CODEX_HOME ?? path.join(home, '.codex'), 'skills');
    case 'claude':
      return path.resolve(env.CLAUDE_CONFIG_DIR ?? path.join(home, '.claude'), 'skills');
    case 'agents':
      return path.resolve(home, '.agents', 'skills');
    default:
      throw new Error(`Unsupported agent '${agent}'. Choose: ${supportedAgents.join(', ')}, or all.`);
  }
}

export function resolveAgentSelection(selection, options = {}) {
  if (selection === undefined || selection === null || String(selection).trim() === '') {
    throw new Error('At least one --agent is required.');
  }
  const names = selection === 'all'
    ? supportedAgents
    : String(selection).split(',').map((value) => value.trim()).filter(Boolean);
  const unique = [...new Set(names)];
  if (unique.length === 0) {
    throw new Error('At least one --agent is required.');
  }
  return unique.map((agent) => ({ agent, root: resolveAgentSkillRoot(agent, options) }));
}
