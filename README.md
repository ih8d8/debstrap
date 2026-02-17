# debstrap

Ansible roles to harden and set up a baseline configuration on a Debian-based VPS. Covers system packages, SSH hardening, Docker, Tailscale, firewall (UFW), fail2ban, and IP-based geoblocking.

## What it does

- **System packages** - Installs common utilities (htop, tmux, curl, vnstat, tcpdump, etc.)
- **SSH hardening** - Disables password authentication, enforces pubkey-only login, disables empty passwords
- **Docker** - Installs Docker CE from the official repo, configures log rotation, creates a Docker network, and installs [ufw-docker](https://github.com/chaifeng/ufw-docker) to fix UFW/Docker port-bypass issues
- **Tailscale** - Installs and enables the Tailscale daemon for private mesh networking
- **UFW** - Enables the firewall with port 22 allowed (IPv4 only)
- **fail2ban** - Configures incremental ban times, ignores private/tailscale subnets
- **IPv6 disabled** - Disables IPv6 via sysctl
- **Journal limits** - Caps systemd-journald storage
- **Geoblocking** - Blocks entire countries at the network level using ipset (see below)

## Geoblocking

The vps_baseline role deploys an ipset-based geoblocking system that drops all traffic from configured countries before it reaches any service, including Docker-exposed ports.

How it works:

1. A script (`update-geoblock.sh`) downloads aggregated CIDR lists from [ipdeny.com](https://www.ipdeny.com) for each country listed in `vars/main.yaml` under `blocked_countries`
2. The CIDRs are loaded into an ipset called `geoblock`, then atomically swapped in so there's no gap in protection
3. iptables rules are inserted into both `ufw-before-input` and `DOCKER-USER` chains to DROP packets matching the ipset
4. A systemd service (`ipset-geoblock-restore`) restores the ipset and iptables rules on boot
5. A weekly cron job refreshes the CIDR lists

To change which countries are blocked, edit `roles/vps_baseline/vars/main.yaml`:

```yaml
blocked_countries:
  - cn
  - ru
  - br
  - vn
```

Country codes are two-letter ISO 3166-1 alpha-2 codes.

## Adding services

The project is structured so you can add more roles alongside `vps_baseline`. An **ntopng** role is included as an example — it deploys [ntopng](https://www.ntop.org/products/traffic-analysis/ntopng/) as a Docker container for real-time network traffic monitoring.

To add your own service, create a new role under `roles/` and add it to `playbooks/vps.yaml`. You can run individual roles using tags:

```bash
ansible-playbook playbooks/vps.yaml --tags ntopng
```

### ntopng

ntopng runs in `network_mode: host` so it can capture traffic on the server's main interface. By default it listens on `127.0.0.1:3000`, meaning it's not exposed to the internet.

To access the web UI, use SSH port forwarding:

```bash
ssh -L 3000:127.0.0.1:3000 root@your-server
# then open http://localhost:3000 in your browser
```

If you've added the VPS to your Tailscale tailnet, you can set `ntopng_listen_address` to the server's Tailscale IP in `roles/ntopng/vars/main.yaml` and access ntopng directly from any device on your tailnet — no port forwarding needed:

```yaml
ntopng_listen_address: 100.x.y.z  # your server's Tailscale IP
```

## Usage

1. Edit `inventory` with your server's IP and SSH key path
2. Adjust variables in `roles/vps_baseline/vars/main.yaml` if needed
3. Run the playbook:

```bash
ansible-playbook playbooks/vps.yaml
```
