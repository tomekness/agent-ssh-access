Hostname: tmkpi4
Port: 1001
User: agentuser
Key: ~/.ssh/id_agentuser

SAFE_PATHS
- /etc
- /home/agentuser
- /var/log
- /proc

Notes
- agentuser has NOPASSWD: ALL sudo via /etc/sudoers.d/agentuser
- Docker containers running: n8n (port 5000), open-webui (port 3000)
- agentuser is NOT in the docker group — use `sudo docker` for Docker commands
