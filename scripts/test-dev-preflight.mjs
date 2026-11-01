#!/usr/bin/env node
/**
 * Apple Expert — the check that runs before `npm run dev`.
 *
 *   node --test scripts/test-dev-preflight.mjs
 *
 * Runs the real script in a throwaway project with a fake `docker` on the PATH, so
 * it never touches the local stack or the real supabase/.env.
 */

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const SCRIPT = resolve('scripts/dev-preflight.mjs')
const COMPLETE_ENV = 'SEND_SMS_HOOK_SECRET=hook-value\nSMSLENZ_USER_ID=user-value\nSMSLENZ_API_KEY=key-value\nSMSLENZ_SENDER_ID=sender-value\n'

function run({ docker, env }) {
  const dir = mkdtempSync(join(tmpdir(), 'dev-preflight-'))
  try {
    mkdirSync(join(dir, 'supabase'))
    mkdirSync(join(dir, 'bin'))
    writeFileSync(join(dir, 'supabase', 'config.toml'), 'project_id = "test-project"\n')
    if (env !== undefined) writeFileSync(join(dir, 'supabase', '.env'), env)
    if (docker) {
      writeFileSync(join(dir, 'bin', 'docker'), `#!/bin/sh\n${docker}\n`)
      chmodSync(join(dir, 'bin', 'docker'), 0o755)
    }
    const result = spawnSync(process.execPath, [SCRIPT], { cwd: dir, env: { PATH: join(dir, 'bin') }, encoding: 'utf8' })
    return { status: result.status, output: result.stdout + result.stderr }
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

const RUNNING = 'echo true'

test('everything in place: passes silently', () => {
  const { status, output } = run({ docker: RUNNING, env: COMPLETE_ENV })
  assert.equal(status, 0)
  assert.equal(output, '')
})

test('Supabase stopped: tells you the command, and exits', () => {
  const { status, output } = run({ docker: 'echo false', env: COMPLETE_ENV })
  assert.equal(status, 1)
  assert.match(output, /npx supabase start/)
})

test('containers removed: treated as not running', () => {
  const { status, output } = run({ docker: 'echo "Error: No such container" >&2; exit 1', env: COMPLETE_ENV })
  assert.equal(status, 1)
  assert.match(output, /not running/)
})

test('Docker daemon down, or not installed: says to check Docker', () => {
  const down = run({ docker: 'echo "Cannot connect to the Docker daemon" >&2; exit 1', env: COMPLETE_ENV })
  assert.equal(down.status, 1)
  assert.match(down.output, /Is Docker running/)
  const absent = run({ env: COMPLETE_ENV })
  assert.equal(absent.status, 1)
  assert.match(absent.output, /Is Docker running/)
})

test('supabase/.env missing: exits and creates nothing', () => {
  const { status, output } = run({ docker: RUNNING })
  assert.equal(status, 1)
  assert.match(output, /supabase\/\.env is missing/)
})

test('commented-out or empty variables: warns by name, never by value, and carries on', () => {
  const { status, output } = run({
    docker: RUNNING,
    env: 'SEND_SMS_HOOK_SECRET=hook-value\n# SMSLENZ_USER_ID=user-value\nSMSLENZ_API_KEY=\nSMSLENZ_SENDER_ID=sender-value\n',
  })
  assert.equal(status, 0)
  assert.match(output, /SMSLENZ_USER_ID, SMSLENZ_API_KEY/)
  assert.doesNotMatch(output, /SMSLENZ_SENDER_ID/)
  assert.doesNotMatch(output, /-value/)
})
