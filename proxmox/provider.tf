# Credentials come from the environment, never from files:
#   export PROXMOX_VE_API_TOKEN='terraform@pve!tofu=<secret>'
provider "proxmox" {
  # MagicDNS name over Tailscale: works at home and away.
  endpoint = "https://pve1:8006/"
  insecure = true # Proxmox's default self-signed certificate
}
