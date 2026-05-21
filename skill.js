'use strict';

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// Walk up from startDir looking for agent-ssh-access/
function findProject(startDir) {
  let dir = path.resolve(startDir);
  for (let i = 0; i < 8; i++) {
    const candidate = path.join(dir, 'agent-ssh-access');
    if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function listHosts(project) {
  const hostsDir = path.join(project, 'hosts');
  return fs.readdirSync(hostsDir)
    .filter(f => f.endsWith('.md') && f !== 'HOST_TEMPLATE.md')
    .map(f => f.replace('.md', ''));
}

function readHostConfig(project, host) {
  const file = path.join(project, 'hosts', `${host}.md`);
  if (!fs.existsSync(file)) return null;
  const raw = fs.readFileSync(file, 'utf8');
  const get = (key) => { const m = raw.match(new RegExp(`^${key}:\\s*(.+)`, 'm')); return m ? m[1].trim() : null; };
  const safePaths = [...raw.matchAll(/^- (.+)/gm)].map(m => m[1].trim());
  const notes = raw.split(/^Notes/m)[1]?.trim().split('\n').filter(l => l.startsWith('-')).map(l => l.slice(1).trim()) ?? [];
  return {
    hostname: get('Hostname'),
    port: get('Port') || '22',
    user: get('User'),
    key: get('Key')?.replace('~', os.homedir()),
    safePaths,
    notes,
  };
}

function checkSsh(cfg) {
  try {
    execSync(
      `ssh -i ${cfg.key} -p ${cfg.port} -o BatchMode=yes -o ConnectTimeout=5 ${cfg.user}@${cfg.hostname} 'echo ok'`,
      { stdio: 'pipe', timeout: 8000 }
    );
    return true;
  } catch {
    return false;
  }
}

function checkMount(project, host) {
  try {
    const entries = fs.readdirSync(path.join(project, 'mounts', host));
    return entries.length > 0;
  } catch {
    return false;
  }
}

function parseHost(input, hosts) {
  for (const h of hosts) {
    if (input.toLowerCase().includes(h.toLowerCase())) return h;
  }
  return null;
}

async function run(entry) {
  const input = typeof entry === 'string' ? entry : (entry?.content ?? entry?.text ?? '');

  const project = findProject(process.cwd());
  if (!project) {
    return {
      success: false,
      message: 'agent-ssh-access/ directory not found. Clone or create the project first — see https://github.com/tomekness/agent-ssh-access',
    };
  }

  const hosts = listHosts(project);
  if (hosts.length === 0) {
    return {
      success: false,
      message: `No host configs found in ${path.join(project, 'hosts')}. Copy HOST_TEMPLATE.md to get started.`,
    };
  }

  let host = parseHost(input, hosts);
  if (!host && hosts.length === 1) host = hosts[0];
  if (!host) {
    return {
      success: true,
      message: `Available hosts: ${hosts.join(', ')}. Specify one to connect (e.g. "check the pi on mypi").`,
      hosts,
    };
  }

  const cfg = readHostConfig(project, host);
  if (!cfg) {
    return { success: false, message: `Host config not found for '${host}'.` };
  }

  const ssh = checkSsh(cfg);
  const mounted = checkMount(project, host);

  return {
    success: true,
    host,
    hostname: cfg.hostname,
    port: cfg.port,
    user: cfg.user,
    ssh: ssh ? 'reachable' : 'unreachable',
    mount: mounted ? 'active' : 'not mounted',
    safe_paths: cfg.safePaths,
    notes: cfg.notes,
    message: [
      `Host:       ${cfg.hostname} (port ${cfg.port})`,
      `User:       ${cfg.user}  |  Key: ${cfg.key}`,
      `SSH:        ${ssh ? '✓ reachable' : '✗ unreachable'}`,
      `Mount:      ${mounted ? '✓ active' : '✗ not mounted'}`,
      `SAFE_PATHS: ${cfg.safePaths.join(', ')}`,
      cfg.notes.length ? `Notes:      ${cfg.notes.join('; ')}` : '',
    ].filter(Boolean).join('\n'),
  };
}

module.exports = { run };
