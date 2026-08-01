#!/usr/bin/env node

import { main } from '../lib/cli.mjs';

try {
  await main(process.argv.slice(2));
} catch (error) {
  const json = process.argv.includes('--json');
  const message = error instanceof Error ? error.message : String(error);
  if (json) {
    process.stderr.write(`${JSON.stringify({ ok: false, error: message })}\n`);
  } else {
    process.stderr.write(`deliver-code-quality: ${message}\n`);
  }
  process.exitCode = 1;
}
