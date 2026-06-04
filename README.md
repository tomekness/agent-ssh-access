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
cp agent-ssh-access/client/hosts/HOST_TEMPLATE.md agent-ssh-access/client/hosts/<hostname>.md
# fill in Hostname, Port, User, Key, SAFE_PATHS
```

**4. Provision the agent user on the remote host**

You need existing admin SSH access to the remote host for this step (your normal user, not agentuser).

```bash
# Step 1 — generate keypair locally (once, skipped if already exists)
cd agent-ssh-access
./client/create_key.sh

# Step 2 — copy server_setup/ to the remote
scp -r server_setup/ admin@<hostname>:~/

# Step 3 — install agentuser on the remote
cat ~/.ssh/id_agentuser.pub | ssh admin@<hostname> 'sudo bash ~/server_setup/01_install.sh [--sudo]'
```

- `--sudo` adds a `NOPASSWD: ALL` sudoers entry — required if you want the agent to run `sudo` commands without a password prompt
- See `server_setup/README.md` for all options (IP restriction, activate/deactivate/remove)

Then verify the login works:

```bash
./client/test_login.sh --host <hostname> --port <port> --key ~/.ssh/id_agentuser
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
├── AGENT_INSTRUCTIONS.md # fallback for agents without skill support
├── skill.js              # OpenCode skill helper
├── install.js / package.json
├── LICENSE / README.md
│
├── client/               # client-side scripts + runtime data (run on your agent machine)
│   ├── create_key.sh         # generate local ~/.ssh/id_agentuser keypair (once)
│   ├── activate_access.sh    # remotely unlock agentuser (restore shell)
│   ├── deactivate_access.sh  # remotely block agentuser login (set shell to nologin)
│   ├── revoke_access.sh      # remotely remove key + sudoers entry
│   ├── mount_sshfs.sh        # mount a host via SSHFS
│   ├── unmount.sh            # unmount
│   ├── test_login.sh         # verify SSH + sudo work
│   ├── session_logger.sh     # append structured lines to session.log
│   ├── hosts/
│   │   ├── HOST_TEMPLATE.md  # copy this to add a new host
│   │   └── <hostname>.md     # your host configs (gitignored)
│   ├── mounts/
│   │   └── <hostname>/       # SSHFS mount root (auto-created, gitignored)
│   └── session.log           # audit log (gitignored)
│
└── server_setup/         # server-side scripts — copy this folder to the remote host
    ├── 01_install.sh     # create agentuser + install public key
    ├── 02_activate.sh    # unlock user account
    ├── 03_deactivate.sh  # lock user account (reversible)
    ├── 04_remove.sh      # delete user + home + sudoers
    └── README.md
```

---

## How it works

### Plan / go protocol

The agent never executes anything without explicit approval:

1. The agent prints a numbered **Plan:** (1–3 steps)
2. For privileged steps (sudo, service restarts), the plan is written to `client/session.log` before asking
3. You type `go` on its own line
4. The agent executes — without asking again, unless the plan changes
5. Any other input is treated as a new instruction

### SAFE_PATHS

Each host file defines a `SAFE_PATHS` list. The agent will only read or reference remote files within those paths. If you request something outside SAFE_PATHS, the agent declines and suggests adding the path to the host file.

### Audit log

`client/session.log` records every proposed and confirmed action:

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
- Rotate the key periodically: revoke with `./client/revoke_access.sh`, delete `~/.ssh/id_agentuser`, re-run `./client/create_key.sh` and reinstall via `server_setup/01_install.sh`

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
./client/revoke_access.sh --host <hostname> --port <port> --remote-user <admin> --force-remove-all
```

This removes the public key from `authorized_keys` and deletes the sudoers entry.

---

## License

MIT — see [LICENSE](LICENSE)
