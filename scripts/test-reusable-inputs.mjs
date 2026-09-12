// Run with: node --test scripts/test-reusable-inputs.mjs
// Executes the workflows' actual fixed-runner validation scripts without jobs or secrets.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const bash = process.env.TEST_BASH ?? (process.platform === 'win32'
  ? 'C:/Program Files/Git/bin/bash.exe' : 'bash');
const linux = '["self-hosted","Linux","X64","seolith-local","node-capable"]';
const windows = '["self-hosted","Windows","X64","seolith-local"]';
const shortWindows = '["self-hosted","Windows","X64"]';
const lowerWindows = '["self-hosted","windows","x64"]';
const linuxBuild = '["self-hosted","Linux","X64","seolith-local","linux-build"]';
const levels = ['info', 'low', 'moderate', 'high', 'critical'];
const workflows = [
  { name: 'angular-build-lint', input: 'audit-level', env: 'AUDIT_LEVEL', values: levels,
    fallback: 'critical', runner: windows,
    runners: [windows, shortWindows, lowerWindows, linuxBuild, linux, '["self-hosted","linux","x64"]'] },
  { name: 'node-build', input: 'audit-level', env: 'AUDIT_LEVEL', values: levels,
    fallback: 'high', runner: linux, runners: [linux, lowerWindows] },
  { name: 'node-pwa-build', input: 'audit-level', env: 'AUDIT_LEVEL', values: levels,
    fallback: 'high', runner: linux, runners: [linux, shortWindows, lowerWindows] },
  { name: 'pages-deploy', input: 'package-manager', env: 'PACKAGE_MANAGER', values: ['npm', 'pnpm'],
    fallback: 'npm', runner: linuxBuild,
    runners: [linuxBuild, '["self-hosted", "Linux", "seolith-local", "always-on"]'] },
];

function readWorkflow(name) {
  const source = readFileSync(join(root, '.github', 'workflows', name + '.yml'), 'utf8').replaceAll('\r\n', '\n');
  // Deliberately extract only this fixed-format job; actionlint validates the full YAML schema.
  const resolver = source.match(/^  resolve-runner:\n([\s\S]*?)(?=^  [\w-]+:)/m)?.[1];
  assert.ok(resolver, `${name}: fixed validation job was not found`);
  const script = resolver.match(/^        run: \|\n((?: {10}[^\n]*\n|\n)+)/m)?.[1];
  assert.ok(script, `${name}: validation script was not found`);
  return { source, resolver, script: script.replace(/^ {10}/gm, '') };
}

function runValidation(script, config, value, runner = config.runner) {
  const tempRoot = resolve(tmpdir());
  const directory = mkdtempSync(join(tempRoot, 'seolith-workflow-inputs-'));
  const output = join(directory, 'github-output');
  try {
    const result = spawnSync(bash, ['-s'], {
      input: script,
      encoding: 'utf8',
      timeout: 10_000,
      env: { ...process.env, REQUESTED: runner, [config.env]: value,
        GITHUB_OUTPUT: output.replaceAll('\\', '/') },
    });
    if (result.error) throw result.error;
    let emitted = '';
    try { emitted = readFileSync(output, 'utf8'); } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    return { ...result, emitted };
  } finally {
    const target = resolve(directory);
    assert.ok(target.startsWith(tempRoot + sep) && target !== tempRoot);
    rmSync(target, { recursive: true });
  }
}

for (const config of workflows) {
  const { source, resolver, script } = readWorkflow(config.name);
  test(`${config.name}: reusable input schema and guarded job dependency`, () => {
    const input = source.match(new RegExp(`^      ${config.input}:\\n([\\s\\S]*?)(?=^      [\\w-]+:|^    secrets:)`, 'm'))?.[1];
    assert.ok(input, 'input declaration missing');
    assert.match(input, /^        type: string$/m);
    assert.doesNotMatch(input, /^        options:/m);
    assert.match(input, new RegExp(`^        default: "${config.fallback}"$`, 'm'));
    assert.match(resolver, /^    runs-on: \[self-hosted, Linux, X64\]$/m);
    assert.match(resolver, /^    permissions: \{\}$/m);
    assert.match(source, /needs: \[resolve-runner\][\s\S]*?runs-on: \$\{\{ fromJSON\(needs\.resolve-runner\.outputs\.runs-on\) \}\}/);
    assert.match(source, new RegExp(`needs\\.resolve-runner\\.outputs\\.${config.input}`));
  });
  for (const value of config.values) {
    test(`${config.name}: accepts ${value} and emits only validated selections`, () => {
      const result = runValidation(script, config, value);
      assert.equal(result.status, 0, result.stderr || result.stdout);
      assert.equal(result.emitted, `runs-on=${config.runner}\n${config.input}=${value}\n`);
    });
  }
  for (const value of ['', 'HIGH', 'unsupported', 'high --omit=dev', 'high; exit 0', '$(printf injected)', 'high\nextra-output=bad']) {
    test(`${config.name}: rejects invalid ${JSON.stringify(value)} before outputs`, () => {
      const result = runValidation(script, config, value);
      assert.notEqual(result.status, 0);
      assert.equal(result.emitted, '');
    });
  }
  for (const runner of config.runners) {
    test(`${config.name}: retains approved runner ${runner}`, () => {
      const result = runValidation(script, config, config.fallback, runner);
      assert.equal(result.status, 0, result.stderr || result.stdout);
      assert.equal(result.emitted, `runs-on=${runner}\n${config.input}=${config.fallback}\n`);
    });
  }
  for (const runner of ['["ubuntu-latest"]', '["self-hosted","unapproved"]']) {
    test(`${config.name}: rejects unapproved runner ${runner}`, () => {
      const result = runValidation(script, config, config.fallback, runner);
      assert.notEqual(result.status, 0);
      assert.equal(result.emitted, '');
    });
  }
}
