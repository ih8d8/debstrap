# debstrap

Ansible roles to harden and set up a baseline configuration on a Debian-based VPS. Covers system packages, SSH hardening, Docker, Tailscale, firewall (UFW), fail2ban, and IP-based geoblocking. Includes example service roles for [Headscale](https://github.com/juanfont/headscale) (self-hosted Tailscale coordination server) and [ntopng](https://www.ntop.org/products/traffic-analysis/ntopng/) (real-time traffic monitoring).

## What it does

- **System packages** - Installs common utilities (htop, tmux, curl, vnstat, tcpdump, etc.)
- **SSH hardening** - Disables password authentication, enforces pubkey-only login, disables empty passwords
- **Docker** - Installs Docker CE from the official repo, configures log rotation, creates a Docker network, and installs [ufw-docker](https://github.com/chaifeng/ufw-docker) to fix UFW/Docker port-bypass issues
- **Tailscale** - Installs and enables the Tailscale daemon. Once the VPS is part of your tailnet, you can access services bound to the Tailscale IP from any device on the network without exposing them to the public internet. The headscale role below lets you self-host the coordination server itself
- **UFW** - Enables the firewall with port 22 allowed (IPv4 only)
- **fail2ban** - Configures incremental ban times, ignores private/tailscale subnets
- **IPv6 disabled** - Disables IPv6 via sysctl
- **Journal limits** - Caps systemd-journald storage
- **Geoblocking** - Blocks entire countries at the network level using ipset (see below)
- **Headscale** - Self-hosted Tailscale coordination server behind Nginx Proxy Manager, with helper scripts for user/node management and fail2ban integration
- **ntopng** - Real-time network traffic monitoring via a Docker container, accessible over SSH port forwarding or Tailscale

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

The project is structured so you can add more roles alongside `vps_baseline`. Two example service roles are included: **ntopng** and **headscale**.

To add your own service, create a new role under `roles/` and add it to `playbooks/vps.yaml`. You can run individual roles using tags:

```bash
ansible-playbook playbooks/vps.yaml --tags ntopng
ansible-playbook playbooks/vps.yaml --tags headscale
```

### ntopng

[ntopng](https://www.ntop.org/products/traffic-analysis/ntopng/) provides real-time network traffic monitoring via a web UI. It runs in `network_mode: host` so it can capture traffic on the server's main interface. By default it listens on `127.0.0.1:3000`, meaning it's not exposed to the internet.

To access the web UI, use SSH port forwarding:

```bash
ssh -L 3000:127.0.0.1:3000 root@your-server
# then open http://localhost:3000 in your browser
```

If you've added the VPS to your Tailscale tailnet, you can set `ntopng_listen_address` to the server's Tailscale IP in `roles/ntopng/vars/main.yaml` and access ntopng directly from any device on your tailnet — no port forwarding needed:

```yaml
ntopng_listen_address: 100.x.y.z # your server's Tailscale IP
```

### headscale

[Headscale](https://github.com/juanfont/headscale) is a self-hosted, open source implementation of the Tailscale coordination server. This role deploys headscale behind [Nginx Proxy Manager](https://nginxproxymanager.com/) (NPM) for TLS termination and reverse proxying.

#### Before deploying

1. **Get a domain.** You need a domain (e.g. `example.com`) so that headscale can be reached over HTTPS. Point a DNS record for `example.com` to your server's public IP.

2. **Edit `roles/headscale/files/config.yaml`:**
   - Set `server_url` to your domain, e.g. `https://headscale.example.com`.
   - Under the `dns` section, set `base_domain` to a domain that is **not resolvable from the public internet**. This is used for MagicDNS (e.g. `headscale.tailnet`). You can verify it's not resolvable with `nslookup headscale.tailnet` — it should return NXDOMAIN.
   - Optionally add `dns.extra_records` to create DNS entries for services on your tailnet.

3. **Edit `roles/headscale/files/acl.json`** — replace `your-username@` with the username you'll create later. This ACL policy allows your devices (`group:admin`) to reach everything in the tailnet, including the VPS. However, the VPS itself — registered with `tag:untrusted` — cannot initiate connections to any other device. This is intentional: since the VPS is internet-facing and more exposed to compromise, it should not be able to reach into your private devices. Your devices can still connect to the VPS (e.g. to access ntopng or other services bound to the Tailscale IP), but traffic in the other direction is blocked by the ACL.

#### Setting up Nginx Proxy Manager

After deploying, NPM's admin panel is available on port 81 (localhost only). Access it via SSH port forwarding:

```bash
ssh root@<server_ip> -L 8181:localhost:81
```

Then open `http://localhost:8181` in your browser. Default credentials are `admin@example.com` / `changeme`.

Once logged in:

1. **Add an SSL certificate** — go to SSL Certificates, add a wildcard Let's Encrypt certificate for your domain (e.g. `example.com`, `*.example.com`).
2. **Add a proxy host** — create a new proxy host for `headscale.example.com` pointing to `headscale:8080`, enable the SSL certificate, and turn on **WebSocket support**.

Your headscale coordination server is now accessible at `https://headscale.example.com`.

#### Managing users and nodes

SSH into your server and navigate to `/root/headscale/`. The following helper scripts are available:

- `create-user.sh` — create a new headscale user
- `create-preauthkey.sh` — generate a preauth key for a user or an untrusted device (tagged)
- `create-api-key.sh` — generate an API key
- `register-node.sh` — register a node with a machine key
- `list-nodes.sh` — list all registered nodes

#### Connecting clients

To register the node, either use a preauth key (`create-preauthkey.sh`) or manually register it on the server with `register-node.sh`. Use preauth keys when you want to add devices like an OPNsense Tailscale client where interactive registration isn't practical.

Install the Tailscale client on your devices (Linux, Android, macOS, OPNsense, etc.) and point it to your headscale server. On Unix-based systems, one option is to authenticate using a pre-auth key and join the Headscale tailnet with the following command. You may set the flags as needed:

```bash
sudo tailscale up --auth-key="{your preshared key}" --login-server=https://headscale.example.com --accept-dns=false --operator=${USER}
```

On Android/iOS, change the coordination server URL in the Tailscale app settings to your headscale URL before signing in.


The role also deploys **fail2ban rules** for NPM to ban IPs that repeatedly hit error pages.

## Usage

1. Edit `inventory` with your server's IP and SSH key path
2. Adjust variables in `roles/vps_baseline/vars/main.yaml` if needed
3. Run the playbook:

```bash
ansible-playbook playbooks/vps.yaml
```

To re-apply changes without losing Docker volumes (e.g. headscale database, ntopng data), skip the container teardown step:

```bash
ansible-playbook playbooks/vps.yaml --skip-tags docker-remove
```
