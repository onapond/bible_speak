#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

node - <<'NODE'
const fs = require('fs');
const aliases = JSON.parse(fs.readFileSync('.firebaserc', 'utf8')).projects;
if (aliases.default) throw new Error('A default Firebase project is forbidden');
if (aliases.dev !== 'bible-speak-dev') throw new Error('dev alias mismatch');
if (aliases.prod !== 'bible-speak') throw new Error('prod alias mismatch');

const dev = fs.readFileSync('lib/firebase_options_dev.dart', 'utf8');
const prod = fs.readFileSync('lib/firebase_options_prod.dart', 'utf8');
if (!dev.includes("projectId: 'bible-speak-dev'")) throw new Error('dev client config mismatch');
if (!prod.includes("projectId: 'bible-speak'")) throw new Error('prod client config mismatch');

const rules = fs.readFileSync('firestore.rules', 'utf8');
if (/allow\s+read\s*,\s*write\s*:\s*if\s+true/.test(rules)) {
  throw new Error('public Firestore rules are forbidden');
}

const authWorkflow = fs.readFileSync('.github/workflows/development-auth-smoke.yml', 'utf8');
for (const required of [
  "github.ref == 'refs/heads/develop'",
  'environment: development',
  'FIREBASE_PROJECT_ID: bible-speak-dev',
  "inputs.confirmation == 'SMOKE bible-speak-dev'",
]) {
  if (!authWorkflow.includes(required)) throw new Error(`development Auth boundary missing: ${required}`);
}
if (authWorkflow.includes("refs/heads/master") || authWorkflow.includes('environment: production')) {
  throw new Error('development Auth workflow must not target production');
}
NODE

python3 -m unittest tool.tests.test_agent_harness
echo "Environment contract checks passed."
