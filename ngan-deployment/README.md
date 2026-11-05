# Ngan deployment notes

Config and persona files for a personal OpenClaw (2026.10.4) deployment. Personal data and secrets are intentionally excluded.

- SOUL.md: agent persona and behaviour rules (long jobs, progress messages, latest-message priority).
- ngan-watchdog.sh: systemd timer script (every 2 min). Restarts the gateway, re-enables the Telegram channel, and auto-runs sessions.reset on repeated 400 INVALID_ARGUMENT. Needs NGAN_OWNER_CHAT_ID and a bot token in ~/media_download/.env.
- Config changes made: plugins.entries.antigravity.config.skipPermissions=true, agents.defaults.timeoutSeconds=172800, messages.queue.mode=steer.
