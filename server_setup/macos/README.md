# server_setup/macos — Agent User Installer for macOS

macOS-specific scripts to create, manage, and remove the SSH agent user.
For Linux hosts, use the scripts in `server_setup/` instead.

---

## Differences from Linux

| Aspect | Linux | macOS |
|--------|-------|-------|
| User creation | `useradd` | `dscl` |
| User locking | `usermod -L` | rename `authorized_keys` to `.off` |
| Sudo grants | `/etc/sudoers.d/` | `/etc/sudoers.d/` (same) |
| Home location | `/home/<user>` | `/Users/<user>` or custom volume |
| SSH toggle | lock account | rename `authorized_keys` |

### Custom home directory

macOS allows placing the agent home on a separate volume (e.g. `/Volumes/DataDisk/agent-home`).
This keeps all agent data isolated from the system volume.

Pass `--home /Volumes/DataDisk/agent-home` to every script that accepts it.

---

## Quick start

### 1. Generate a key on your agent machine (once)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_agentuser -N ""
```

### 2. Run the installer on the Mac (with sudo)

```bash
# Standard home (/Users/agentuser)
cat ~/.ssh/id_agentuser.pub | ssh admin@<mac-ip> 'sudo bash ~/server_setup/macos/01_install.sh'

# Custom home on a separate volume
cat ~/.ssh/id_agentuser.pub | ssh admin@<mac-ip> \
  'sudo bash ~/server_setup/macos/01_install.sh --home /Volumes/DataDisk/agent-home'
```

### 3. Test the connection

```bash
ssh -i ~/.ssh/id_agentuser agentuser@<mac-ip> 'whoami'
```

---

## The 4 scripts

| Script | What it does |
|--------|--------------|
| `01_install.sh` | Creates the user, installs the public key, enables Remote Login |
| `02_activate.sh` | Re-enables SSH (restores `authorized_keys` from `.off`) |
| `03_deactivate.sh` | Blocks SSH without removing user or keys (renames to `.off`) |
| `04_remove.sh` | Permanently deletes user and home directory |

All scripts accept `--user NAME` and `--home PATH` to match your installation.

---

## Deactivate vs. Remove

- **Temporary block** (e.g. when not in use):
  ```bash
  sudo ./03_deactivate.sh --home /Volumes/DataDisk/agent-home
  # Restore with:
  sudo ./02_activate.sh   --home /Volumes/DataDisk/agent-home
  ```

- **Permanent removal:**
  ```bash
  sudo ./04_remove.sh --home /Volumes/DataDisk/agent-home
  ```

---

## No sudo grants by default

Unlike the Linux setup, the macOS scripts do **not** configure sudo.
The agent user is a non-admin account with:
- SSH key access only (no password login)
- ACL-based read/write on designated directories
- Docker group membership (if Docker Desktop is installed)

This is intentional — on macOS, Docker Desktop provides container management
without requiring sudo, making a passwordless sudo grant unnecessary.

### Optional: restrict Docker socket access

If you want the agent to use Docker without being in the `docker` group,
use a Docker socket proxy instead (e.g. `ghcr.io/tecnativa/docker-socket-proxy`).

---

## Enable Remote Login manually

If the script cannot enable Remote Login automatically:

```
System Settings → General → Sharing → Remote Login → ON
→ Allow access for: All users  (or select specific users)
```

---

## Lifecycle

```
01_install.sh       → user active, SSH works
03_deactivate.sh    → SSH blocked (keys preserved)
02_activate.sh      → SSH restored
04_remove.sh        → user and home deleted (final)
```
