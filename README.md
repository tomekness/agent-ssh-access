# agent-ssh-access

Safe, auditable SSH access to remote Linux servers and Raspberry Pis for AI agents — works with **Claude Code**, **OpenCode**, and any agent that supports skills or custom instructions.

This lets the agent directly manage Docker or anything else running on the remote server or Pi.

Every action requires explicit human approval via a **plan / go** protocol before anything runs on the remote host.

---

## Install

**1. Clone the repo into your project**

```bash
git clone https://github.com/tomekness/agent-ssh-access
```

This directory is both the project folder and the skill source — the shell scripts and host configs all live here.

**2. Install the skill for your agent**

#### Via npx (recommended)

```bash
# Interactive — asks which agent to install for
npx github:tomekness/agent-ssh-access

# Or specify directly
npx github:tomekness/agent-ssh-access claude-code
npx github:tomekness/agent-ssh-access opencode
npx github:tomekness/agent-ssh-access both
```

#### Manually — Claude Code

```bash
mkdir -p ~/.claude/skills/agent-ssh-access
cp agent-ssh-access/SKILL.md ~/.claude/skills/agent-ssh-access/
```

Restart Claude Code — the skill is active in the next session as `/agent-ssh-access [host]`.

#### Manually — OpenCode

```bash
mkdir -p ~/.config/opencode/skills/agent-ssh-access
cp agent-ssh-access/SKILL.md agent-ssh-access/skill.js \
   ~/.config/opencode/skills/agent-ssh-access/
```

Add to your `opencode.json`:

```json
{
  "skills": {
    "agent-ssh-access": "allow"
  }
}
```

#### Other agents

Point your agent at `AGENT_INSTRUCTIONS.md` — it contains the full plan/go protocol and SAFE_PATHS rules as plain text:

```
See agent-ssh-access/AGENT_INSTRUCTIONS.md for remote host access rules.
```

**3. Add your first host**

```bash
cp agent-ssh-access/hosts/HOST_TEMPLATE.md agent-ssh-access/hosts/<hostname>.md
# fill in Hostname, Port, User, Key, SAFE_PATHS
```

**4. Provision the agent user on the remote host**

You need existing admin SSH access to the remote host for this step (your normal user, not agentuser).

```bash
cd agent-ssh-access
./create_access.sh --host <hostname> --port <port> --remote-user <your-admin-user> [--full-sudo]
```

- `--remote-user` is your existing admin account on the remote (e.g. `pi`, `ubuntu`, `tk`)
- `--full-sudo` adds a `NOPASSWD: ALL` sudoers entry — required if you want the agent to run `sudo` commands without a password prompt

The script does two things:
1. Generates a local ed25519 keypair at `~/.ssh/id_agentuser` (skipped if it already exists)
2. Copies the public key to the remote, then **prints the commands you need to run there**

After the script finishes, SSH into the remote as your admin user and run the printed commands. On Debian/Raspberry Pi OS they look like:

```bash
sudo adduser --disabled-password --gecos "" agentuser
sudo mkdir -p /home/agentuser/.ssh
sudo tee -a /home/agentuser/.ssh/authorized_keys < /tmp/id_agentuser_<pid>.pub > /dev/null
sudo chown -R agentuser:agentuser /home/agentuser/.ssh
sudo chmod 700 /home/agentuser/.ssh && sudo chmod 600 /home/agentuser/.ssh/authorized_keys
sudo rm -f /tmp/id_agentuser_<pid>.pub

# if you used --full-sudo:
echo 'agentuser ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/agentuser
sudo chmod 440 /etc/sudoers.d/agentuser && sudo visudo -c
```

> **Note:** The script uses `useradd`. On Debian/Raspberry Pi OS you can use `adduser` instead (shown above) — it creates the home directory automatically and is the Debian-native tool.

Then verify the login works:

```bash
cd agent-ssh-access
./test_login.sh --host <hostname> --port <port> --key ~/.ssh/id_agentuser
```

**5. Use it**

```
/agent-ssh-access <hostname>
```

Or just describe what you want — the skill triggers automatically:

```
check the pi
is docker running?
restart the n8n container
```

---

## Prerequisites

| Dependency | Purpose |
|---|---|
| `ssh` | Remote command execution |
| `sshfs` | Optional — mount remote filesystem locally (`sudo apt install sshfs` / `brew install macfuse`) |
| Claude Code or OpenCode | For the `/agent-ssh-access` skill |

---

## Project layout

```
agent-ssh-access/
├── SKILL.md              # skill instructions — copy to ~/.claude/skills/agent-ssh-access/
├── skill.js              # OpenCode skill helper
├── LICENSE
├── README.md
├── AGENT_INSTRUCTIONS.md # fallback for agents without skill support
├── hosts/
│   ├── HOST_TEMPLATE.md  # copy this to add a new host
│   └── <hostname>.md     # your host configs (gitignored)
├── mounts/
│   └── <hostname>/       # SSHFS mount root (auto-created, gitignored)
├── create_access.sh      # provision agentuser on a new host
├── mount_sshfs.sh        # mount a host via SSHFS
├── unmount.sh            # unmount
├── revoke_access.sh      # remove key + sudoers from host
├── test_login.sh         # verify SSH + sudo work
└── session_logger.sh     # append structured lines to session.log
```

---

## How it works

### Plan / go protocol

The agent never executes anything without explicit approval:

1. The agent prints a numbered **Plan:** (1–3 steps)
2. For privileged steps (sudo, service restarts), the plan is written to `session.log` before asking
3. You type `go` on its own line
4. The agent executes — without asking again, unless the plan changes
5. Any other input is treated as a new instruction

### SAFE_PATHS

Each host file defines a `SAFE_PATHS` list. The agent will only read or reference remote files within those paths. If you request something outside SAFE_PATHS, the agent declines and suggests adding the path to the host file.

### Audit log

`session.log` records every proposed and confirmed action:

```
2026-05-21T09:14:02Z | PLAN      | restart n8n container on mypi
2026-05-21T09:14:10Z | CONFIRMED | agentuser
```

---

## Security notes

### Intended for trusted networks
This tool is designed for use on a **local network or VPN** — not for hosts exposed directly to the internet. It adds a permanent, passphrase-free SSH key with optional passwordless sudo: convenient for a home lab or office network, but a larger attack surface on a public IP.

If you do expose the host to the internet:
- Use a non-standard SSH port
- Enable fail2ban or equivalent brute-force protection
- Restrict `agentuser` to key-based auth only (`PasswordAuthentication no` in `sshd_config`)
- Consider a firewall allowlist for the IP(s) that need access

### Dedicated user
Always use a separate `agentuser` account — never your admin user. This limits blast radius if something goes wrong.

### `--full-sudo` (NOPASSWD: ALL)
> **Warning:** `NOPASSWD: ALL` means a compromised SSH key gives root access to the host. Only use it if you need the agent to perform a wide range of privileged operations and you accept that risk.

Prefer scoped grants instead. Examples:

```bash
# Docker management only
agentuser ALL=(ALL) NOPASSWD: /usr/bin/docker

# Service control only
agentuser ALL=(ALL) NOPASSWD: /bin/systemctl

# Multiple commands
agentuser ALL=(ALL) NOPASSWD: /usr/bin/docker, /bin/systemctl, /usr/bin/journalctl
```

Edit `/etc/sudoers.d/agentuser` on the remote host to tighten this after initial setup.

### SSH key has no passphrase
The key at `~/.ssh/id_agentuser` is generated without a passphrase so the agent can use it unattended. This means anyone with read access to your local machine can use it. Protect it:

- Keep file permissions at `600` (the script sets this automatically)
- Don't copy it into the repo or any shared location
- Rotate the key periodically: revoke with `./revoke_access.sh` and re-run `create_access.sh`

### SAFE_PATHS scope
Broad paths like `/etc` give the agent read access to sensitive files (`/etc/shadow`, `/etc/passwd`, private configs). Prefer explicit paths:

```
# instead of /etc — be specific:
- /etc/nginx/nginx.conf
- /etc/systemd/system/myservice.service
```

### Revoke when done
If you no longer need agent access, remove it immediately:

```bash
./revoke_access.sh --host <hostname> --port <port> --remote-user <admin> --force-remove-all
```

This removes the public key from `authorized_keys` and deletes the sudoers entry.

---

## License

MIT — see [LICENSE](LICENSE)
