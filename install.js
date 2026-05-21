#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const SKILL_NAME = 'agent-ssh-access';

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(r => rl.question(q, a => { rl.close(); r(a.trim()); }));
}

function ensureDir(d) { fs.mkdirSync(d, { recursive: true }); }

function updateOpenCodeConfig(configFile) {
  let conf = {};
  if (fs.existsSync(configFile)) {
    try { conf = JSON.parse(fs.readFileSync(configFile, 'utf-8')); } catch {}
  }
  if (!conf.$schema) conf.$schema = 'https://opencode.ai/config.json';
  if (!conf.permission) conf.permission = {};
  if (!conf.permission.skill) conf.permission.skill = {};
  conf.permission.skill[SKILL_NAME] = 'allow';
  fs.writeFileSync(configFile, JSON.stringify(conf, null, 2) + '\n');
}

async function main() {
  const arg = (process.argv[2] || '').toLowerCase();

  let platform = arg;
  if (!['claude-code', 'opencode', 'both'].includes(platform)) {
    const ans = await ask('Install for which agent? [c=Claude Code / o=OpenCode / b=both]: ');
    const a = ans.toLowerCase();
    if (a.startsWith('c')) platform = 'claude-code';
    else if (a.startsWith('o')) platform = 'opencode';
    else platform = 'both';
  }

  const installed = [];

  if (platform === 'claude-code' || platform === 'both') {
    const skillDir = path.join(os.homedir(), '.claude', 'skills', SKILL_NAME);
    ensureDir(skillDir);
    fs.copyFileSync(path.join(__dirname, 'SKILL.md'), path.join(skillDir, 'SKILL.md'));
    installed.push(`Claude Code: ${skillDir}`);
  }

  if (platform === 'opencode' || platform === 'both') {
    const skillDir = path.join(os.homedir(), '.config', 'opencode', 'skills', SKILL_NAME);
    const configFile = path.join(os.homedir(), '.config', 'opencode', 'opencode.json');
    ensureDir(skillDir);
    ensureDir(path.dirname(configFile));
    fs.copyFileSync(path.join(__dirname, 'SKILL.md'), path.join(skillDir, 'SKILL.md'));
    if (fs.existsSync(path.join(__dirname, 'skill.js'))) {
      fs.copyFileSync(path.join(__dirname, 'skill.js'), path.join(skillDir, 'skill.js'));
    }
    updateOpenCodeConfig(configFile);
    installed.push(`OpenCode: ${skillDir}`);
  }

  console.log(`\n✓ ${SKILL_NAME} installed`);
  installed.forEach(l => console.log(`  ${l}`));
  console.log('\nNote: also clone the repo into your project for the SSH scripts:');
  console.log('  git clone https://github.com/tomekness/agent-ssh-access');
  console.log('\nRestart your agent to activate the skill.');
}

main().catch(err => { console.error('Install failed:', err.message); process.exit(1); });
