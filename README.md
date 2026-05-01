# dc-time-sync

**Kerberos clock skew helper for AD pentesting labs**

Calculates the time offset between your machine and a Domain Controller,
generates the correct `faketime` prefix, and suggests ready-to-run commands
for your existing `.ccache` tickets.

---

## Features

- Reads DC time via LDAP (no credentials needed)
- Calculates exact offset and rounds to nearest hour (Kerberos-safe)
- Auto-detects `.ccache` files in the current directory
- Generates ready-to-use commands for:
  - `impacket-getTGT`
  - `bloodhound-python`
  - `certipy-ad`
  - `evil-winrm`
  - `impacket-secretsdump`

---

## Requirements

```bash
pip install ldap3
sudo apt install faketime
```

---

## Usage

```bash
# Basic — auto-detect offset
python3 dc_time_sync.py <DC_IP>

# Specify domain
python3 dc_time_sync.py <DC_IP> --domain corp.htb

# Wrap a specific command
python3 dc_time_sync.py <DC_IP> --cmd "impacket-getTGT 'domain/user:pass'"
```

---

## Options

| Flag | Description |
|------|-------------|
| `dc_ip` | IP of the Domain Controller |
| `--domain` | Domain name (e.g. `corp.htb`). Defaults to `domain.htb` |
| `--cmd` | Wrap a specific command with the calculated offset |

---

## Notes

- Designed for CTF/lab environments (HackTheBox, TryHackMe, etc.)
- No authentication required to read DC time via LDAP
- `.ccache` files must be in the **current working directory**

---

## Disclaimer

> This tool is intended for **authorized security testing and educational
> use only**. Always obtain proper permission before testing any system.
