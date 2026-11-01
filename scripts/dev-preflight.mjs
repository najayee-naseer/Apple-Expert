#!/usr/bin/env node
/**
 * Runs before `npm run dev`. Development only.
 *
 * The send-sms function needs local Supabase and supabase/.env, and without them it
 * fails with an error that does not say so. This says so. It only ever reads: it
 * never starts or resets Supabase and never creates the file. It prints variable
 * names, never their values.
 */

import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const REQUIRED_CONTAINERS = ['db', 'auth', 'kong']
const SMS_VARIABLES = ['SEND_SMS_HOOK_SECRET', 'SMSLENZ_USER_ID', 'SMSLENZ_API_KEY', 'SMSLENZ_SENDER_ID']

function stop(lines) {
  console.error(`\n[dev] ${lines.join('\n[dev] ')}\n`)
  process.exit(1)
}

/** True, false, or null when Docker itself gave no usable answer. */
function isRunning(container) {
  const result = spawnSync('docker', ['inspect', '--type', 'container', '--format', '{{.State.Running}}', container], {
    encoding: 'utf8',
    timeout: 10_000,
  })
  if (result.error) return null
  if (result.status !== 0) return /no such/i.test(result.stderr) ? false : null
  return result.stdout.trim() === 'true'
}

function activeVariables(file) {
  const active = new Set()
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)\s*=\s*(.*)$/)
    if (match && match[2].replace(/^["']|["']$/g, '').trim() !== '') active.add(match[1])
  }
  return active
}

const projectId = readFileSync(join('supabase', 'config.toml'), 'utf8').match(/^project_id\s*=\s*"([^"]+)"/m)?.[1]
if (!projectId) stop(['Could not read project_id from supabase/config.toml.'])

const states = REQUIRED_CONTAINERS.map((name) => isRunning(`supabase_${name}_${projectId}`))
if (states.includes(null)) {
  stop(['Could not ask Docker about local Supabase. Is Docker running?', 'Start Docker, then run: npx supabase start'])
}
if (states.includes(false)) {
  stop(['Local Supabase is not running. Start it with: npx supabase start', 'Then run: npm run dev'])
}

const envFile = join('supabase', '.env')
if (!existsSync(envFile)) {
  stop(['supabase/.env is missing, so the SMS function cannot start.', 'See "Testing SMS against local Supabase" in docs/customer-auth.md.'])
}

const active = activeVariables(envFile)
const missing = SMS_VARIABLES.filter((name) => !active.has(name))
if (missing.length > 0) {
  console.warn(`\n[dev] Not set in supabase/.env: ${missing.join(', ')}.\n[dev] Phone sign-in will not send codes until they are.\n`)
}
