# homelab

Infrastructure-as-code for my home lab: a [Talos Linux](https://www.talos.dev/) Kubernetes cluster running on Proxmox, and the self-hosted services that live on it.

Everything the cluster runs is declared in this repository. Secrets are committed only in encrypted form with [SOPS](https://github.com/getsops/sops).

## What runs here

**Platform**
- **Talos Linux**: immutable, API-managed Kubernetes OS running as VMs on Proxmox.
- **Flux** (via the Flux Operator): GitOps. The cluster reconciles itself from this repository.
- **Tailscale operator**: private access to services over the tailnet, with HTTPS and no ports open to the internet.
- **CloudNativePG**: PostgreSQL operator for app databases.
- **local-path-provisioner**: node-local storage, plus NFS for bulk media. Never mount a local-path volume with `subPath`: on Talos 1.14 such mounts land in the kubelet's container layer instead of the disk and are lost on reboot.

**Observability**
- **kube-prometheus-stack**: Prometheus, Grafana (GitHub sign-in) and Alertmanager.
- **Loki + Grafana Alloy**: every container's logs and Kubernetes events, searchable in Grafana for 7 days.
- Alerts go to **Telegram**; a **healthchecks.io** heartbeat reports when the whole homelab is down.
- **[Gatus](https://gatus.io/)**: uptime checks for every service, also alerting to Telegram.

**Apps**
- **[Immich](https://immich.app/)**: self-hosted photo and video library, replacing cloud photo storage.
- **[Home Assistant](https://www.home-assistant.io/)**: home automation, running as its own VM on Proxmox.
- **[AdGuard Home](https://adguard.com/adguard-home/overview.html)**: DNS-level ad and tracker blocking for every device on the tailnet.
- **[Copyparty](https://github.com/9001/copyparty)**: web file server for a shared folder on the USB drive; upload and download from any tailnet device's browser, no login.
- **[Vaultwarden](https://github.com/dani-garcia/vaultwarden)**: Bitwarden-compatible password manager, tailnet only.
- **[Homepage](https://gethomepage.dev/)**: start page linking everything, with live status.

**Backups**
- Nightly **restic** backups to **Backblaze B2** (encrypted, versioned) of the Immich database dumps, Home Assistant's backups and Vaultwarden's data. Home Assistant writes its backups to a share on `pve1`.

**Planned**
- Off-site backup of the photo library itself.
- More self-hosted services over time.

## Layout

```
clusters/homelab/ Flux entry point: the FluxInstance and what to sync, in order
infrastructure/   cluster-wide components: storage, operators, networking, monitoring
apps/             self-hosted applications
proxmox/          Proxmox VMs (Home Assistant, Talos nodes), managed with OpenTofu
tailscale/        tailnet access policy and DNS settings, managed with OpenTofu
talos/            Talos cluster secrets (SOPS-encrypted)
```

## Development

- **Updates**: [Renovate](https://docs.renovatebot.com/) opens pull requests for new chart, image, provider and action versions; merging deploys them through Flux.
- **Checks**: [pre-commit](https://pre-commit.com/) runs linting, secret scanning (gitleaks) and [Conventional Commits](https://www.conventionalcommits.org/) message checks locally, and the same checks run in CI on every pull request. Enable them once per clone:

  ```bash
  pre-commit install --hook-type pre-commit --hook-type commit-msg
  ```

## Secrets

Secrets are encrypted with SOPS before they are committed; recipients are configured in `.sops.yaml`. No plaintext credential is ever stored in this repository.

## Restoring from backup

Nightly restic snapshots in B2 hold the Immich database dumps, Home Assistant's backups and Vaultwarden's data (`/backup/immich-db`, `/backup/home-assistant`, `/backup/vaultwarden`). Restoring needs the restic password (`infrastructure/backups/b2.sops.yaml`) and the B2 key, so keep both outside the homelab too.

**Restore drill for Vaultwarden** (tested 2026-10-10): brings the latest snapshot up in a throwaway, RAM-only pod with its own tailnet address. Log in with your master password, check the entries, change nothing, then delete it.

```bash
kubectl apply  -f infrastructure/backups/restore-test/vaultwarden.yaml
# https://vault-restore-test.<tailnet>.ts.net
kubectl delete -f infrastructure/backups/restore-test/vaultwarden.yaml
```

A real restore uses the same files: copy `db.sqlite3`, `rsa_key*` and any `attachments/` / `sends/` from the snapshot into Vaultwarden's volume while the app is scaled to zero, then start it again.

## Rebuilding from scratch

Everything inside the cluster comes back from Git. These are the few one-time steps outside it.

**Needs:** the age key (`~/.config/sops/age/keys.txt`, or the PGP recovery key), `sops`, `tofu`, `talosctl`, `kubectl`, `helm`.

### 1. Proxmox host (`pve1`)

Bulk data (Immich library, backups, shared files) lives on an external USB drive (ext4, label `data`) mounted at `/mnt/data` and shared to the cluster over NFS.

```bash
mkdir -p /mnt/data
echo 'LABEL=data /mnt/data ext4 defaults,nofail,x-systemd.device-timeout=90s 0 2' >> /etc/fstab
mount -a
mkdir -p /mnt/data/immich /mnt/data/shared /mnt/data/vaultwarden-backups /mnt/data/ha-backups

apt install -y nfs-kernel-server
cat >> /etc/exports <<'EOF'
/mnt/data 192.168.1.7(rw,sync,no_subtree_check,no_root_squash,mp,fsid=101) 192.168.1.34(rw,sync,no_subtree_check,no_root_squash,mp,fsid=101)
/mnt/data/ha-backups 192.168.1.40(rw,sync,no_subtree_check,root_squash,mp=/mnt/data) 192.168.1.7(ro,sync,no_subtree_check,mp=/mnt/data) 192.168.1.34(ro,sync,no_subtree_check,mp=/mnt/data)
EOF

# Start NFS only after the drive is mounted (it's slow to appear after a power cut)
mkdir -p /etc/systemd/system/nfs-server.service.d
printf '[Unit]\nRequiresMountsFor=/mnt/data\n' > /etc/systemd/system/nfs-server.service.d/wait-for-usb.conf
systemctl daemon-reload && systemctl restart nfs-server && exportfs -v
```

Ownership inside the drive: `shared/` 1000:1000 (Copyparty), `vaultwarden-backups/` 1000:65534 mode 750, `ha-backups/` 65534:65534. The router has DHCP reservations for `pve1` (.50), the Talos nodes (.34, .7) and Home Assistant (.40); the exports depend on them.

`mp` exports only while the drive is mounted, so an unplugged drive never lets uploads fill the host disk.

Read-only API user for the Prometheus exporter (put the token value into `infrastructure/pve-exporter/token.sops.yaml`):

```bash
pveum user add prometheus@pve --comment "Prometheus exporter (read-only)"
pveum aclmod / -user prometheus@pve -role PVEAuditor
pveum user token add prometheus@pve exporter --privsep 0
```

Login uses a Google OpenID Connect realm (`google`, default on the login page); `root@pam` stays as the break-glass login.

### 2. VMs

OpenTofu needs a Proxmox API token (`terraform@pve!tofu`, roles `PVEVMAdmin` on `/vms`, `PVEDatastoreUser` on `/storage`, `PVEAuditor` on `/`).

```bash
export PROXMOX_VE_API_TOKEN='terraform@pve!tofu=<secret>'
cd proxmox && tofu init && tofu apply
```

The code describes the existing VMs and imports them; creating them from nothing has not been tested.

### 3. Talos cluster

Machine configs are generated from the encrypted secrets bundle and never committed (`talos/generated/` is ignored).

```bash
sops -d talos/talsecret.sops.yaml > /tmp/talsecret.yaml
talosctl gen config talos-proxmox-cluster https://192.168.1.34:6443 \
  --with-secrets /tmp/talsecret.yaml --output talos/generated \
  --install-image factory.talos.dev/metal-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.14.0
rm /tmp/talsecret.yaml

export TALOSCONFIG=talos/generated/talosconfig
talosctl apply-config --insecure -n 192.168.1.34 -f talos/generated/controlplane.yaml
talosctl apply-config --insecure -n 192.168.1.7 -f talos/generated/worker.yaml
talosctl bootstrap -n 192.168.1.34 -e 192.168.1.34
talosctl kubeconfig -n 192.168.1.34 -e 192.168.1.34
```

### 4. Flux

```bash
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --version 0.61.0 --namespace flux-system --create-namespace --wait

kubectl create secret generic sops-age -n flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt

kubectl apply -f clusters/homelab/flux-instance.yaml
```

Flux then installs everything else from `clusters/homelab/` in dependency order. Check progress with `kubectl get kustomizations,helmreleases -A`.
