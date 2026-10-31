terraform {
  required_version = ">= 1.8"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.3"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}
