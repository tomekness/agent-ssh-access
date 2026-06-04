# server_setup — agentuser Installer

Server-seitige Skripte zum Anlegen, Verwalten und Entfernen des `agentuser` SSH-Users.

Einmal auf den Server kopieren, fertig. Kein manuelles Tippen von Befehlen mehr.

---

## Schnellstart

### 1. Key lokal erzeugen (einmalig, auf deiner Agent-Maschine)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_agentuser -N ""
```

### 2. Diesen Ordner auf den Server kopieren

```bash
scp -r server_setup/ admin@DEIN-SERVER:~/
```

### 3. User anlegen (auf dem Server)

```bash
# Ohne IP-Beschränkung
cat ~/.ssh/id_agentuser.pub | ssh admin@DEIN-SERVER 'sudo bash ~/server_setup/01_install.sh'

# Mit IP-Beschränkung (empfohlen) — ersetzt DEINE-IP mit der IP deiner Agent-Maschine
cat ~/.ssh/id_agentuser.pub | ssh admin@DEIN-SERVER 'sudo bash ~/server_setup/01_install.sh --from DEINE-IP'

# Mit IP-Beschränkung + sudo-Rechte
cat ~/.ssh/id_agentuser.pub | ssh admin@DEIN-SERVER 'sudo bash ~/server_setup/01_install.sh --from DEINE-IP --sudo'
```

### 4. Verbindung testen

```bash
ssh -i ~/.ssh/id_agentuser agentuser@DEIN-SERVER 'whoami; id'
```

---

## Die 4 Skripte

| Skript | Was es tut |
|--------|-----------|
| `01_install.sh` | Legt `agentuser` an, trägt den Public Key ein |
| `02_activate.sh` | Entsperrt den User (nach Deaktivierung) |
| `03_deactivate.sh` | Sperrt den User — Keys bleiben erhalten |
| `04_remove.sh` | Löscht User, Home-Verzeichnis und sudoers (unwiderruflich) |

Alle Skripte mit `sudo` ausführen.

---

## Optionen für 01_install.sh

```
--key "ssh-ed25519 AAAA..."   Public Key als String (oder per stdin pipen)
--from IP                      Key nur von dieser IP zulassen (Sicherheits-Empfehlung)
--sudo                         Passwordless sudo für agentuser einrichten
```

---

## Sicherheit: Key an eine IP binden

Ohne `--from` akzeptiert der Server den Key von **überall**. Mit `--from DEINE-IP` wird in der `authorized_keys` folgender Eintrag geschrieben:

```
from="12.34.56.78" ssh-ed25519 AAAA...
```

Das bedeutet: Der Key funktioniert **nur** von dieser IP-Adresse — auch wenn jemand anders den privaten Key in die Hände bekommt, kann er sich **nicht** einloggen.

**Deine Agent-IP herausfinden:**
```bash
curl -s ifconfig.me   # öffentliche IP
# oder
hostname -I           # lokale IP (für LAN-Zugriff)
```

---

## IP-Binding mit dynamischer IP / DDNS

`--from` akzeptiert keine DDNS-Hostnamen (SSH macht keine DNS-Auflösung dafür).
Bei dynamischer IP gibt es zwei saubere Lösungen:

**Tailscale** — empfohlen für dynamische IPs:
Tailscale gibt jedem Gerät eine stabile `100.x.x.x` IP, die sich nie ändert, egal wie oft die öffentliche IP wechselt.

```bash
# Auf Server + Agent-Maschine installieren
curl -fsSL https://tailscale.com/install.sh | sh && tailscale up

# Dann mit der stabilen Tailscale-IP installieren
cat ~/.ssh/id_agentuser.pub | ssh admin@SERVER 'sudo bash ~/server_setup/01_install.sh --from 100.x.x.x'
```

Bonus: SSH-Traffic läuft durch den Tailscale-Tunnel, Port 22 muss nicht mal öffentlich offen sein.

**Firewall-Regel statt Key-Binding** — Alternative ohne Tailscale:
```bash
# Nur diese IP darf auf Port 22
ufw allow from DEINE-IP to any port 22
# Bei IP-Wechsel: alte Regel löschen, neue anlegen
ufw delete allow from ALTE-IP to any port 22
```

---

## Deaktivieren vs. Entfernen

- **Temporär sperren** (z.B. bei Urlaub): `sudo ./03_deactivate.sh` — Keys bleiben, einfach reaktivierbar
- **Dauerhaft entfernen**: `sudo ./04_remove.sh` — löscht alles, auch den lokalen Key danach von Hand löschen

---

## Typischer Lebenszyklus

```
01_install.sh       → User ist aktiv
03_deactivate.sh    → User gesperrt (reversibel)
02_activate.sh      → User wieder aktiv
04_remove.sh        → User gelöscht (final)
```
