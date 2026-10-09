# Tailnet DNS: AdGuard Home (in-cluster, via Tailscale LoadBalancer) for every device.
resource "tailscale_dns_configuration" "this" {
  magic_dns          = true
  override_local_dns = true
  search_paths       = []
  nameservers {
    address            = "100.77.188.57"
    use_with_exit_node = false
  }
}
