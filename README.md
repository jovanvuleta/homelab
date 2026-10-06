# homelab

Infrastructure-as-code for my home lab: a [Talos Linux](https://www.talos.dev/) Kubernetes cluster running on Proxmox, and the self-hosted services that live on it.

Everything the cluster runs is declared in this repository. Secrets are committed only in encrypted form with [SOPS](https://github.com/getsops/sops).

## What runs here

**Platform**
- **Talos Linux**: immutable, API-managed Kubernetes OS running as VMs on Proxmox.
- **Flux**: GitOps. The cluster reconciles itself from this repository.
- **Tailscale operator**: private access to services over the tailnet, with HTTPS and no ports open to the internet.
- **CloudNativePG**: PostgreSQL operator for app databases.
- **local-path-provisioner**: node-local storage, plus NFS for bulk media.

**Apps**
- **[Immich](https://immich.app/)**: self-hosted photo and video library, replacing cloud photo storage.
- **[Home Assistant](https://www.home-assistant.io/)**: home automation, running as its own VM on Proxmox.

**Planned**
- Observability: Prometheus, Grafana and alerting.
- Backups: off-site copies of the photo library and databases.
- More self-hosted services over time.

## Layout

```
proxmox/          Proxmox VMs (Home Assistant, Talos nodes), managed with OpenTofu
talos/            Talos cluster secrets (SOPS-encrypted)
infrastructure/   cluster-wide components: storage, operators, networking
apps/             self-hosted applications
```

## Secrets

Secrets are encrypted with SOPS before they are committed; recipients are configured in `.sops.yaml`. No plaintext credential is ever stored in this repository.
