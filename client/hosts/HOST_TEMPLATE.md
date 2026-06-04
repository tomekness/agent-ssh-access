Hostname: <hostname>
Port: 22
User: agentuser
Key: ~/.ssh/id_agentuser

SAFE_PATHS
- /home/agentuser
- /var/log
- /proc

Notes
- Replace SAFE_PATHS with the minimal set needed for your use case.
- Keep paths explicit — prefer /var/log/syslog over /var/log where possible.
- Document any sudo grants or group memberships that affect what the agent can do.

Example — diagnostics only
- /etc/os-release
- /etc/hostname
- /proc/cpuinfo
- /proc/meminfo
- /proc/uptime
- /proc/loadavg
- /var/log/syslog
- /var/log/auth.log

Example — full read access
- /etc
- /home/agentuser
- /var/log
- /proc
