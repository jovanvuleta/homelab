# Least access: people reach everything, machines reach nothing.
# Cluster services (tag:k8s) and servers (tag:server) only answer
# connections, so a compromised one can't pivot to other devices.
resource "tailscale_acl" "this" {
  acl = jsonencode({
    tagOwners = {
      "tag:k8s-operator" = ["autogroup:admin"]
      "tag:k8s"          = ["tag:k8s-operator"] # the operator tags the proxies it creates
      "tag:server"       = ["autogroup:admin"]  # pve1, Home Assistant
    }

    autoApprovers = {
      services = { "tag:k8s" = ["tag:k8s"] } # operator-managed Tailscale Services
    }

    grants = [
      {
        # Your own devices (Mac, iPhone): every service and server.
        src = ["autogroup:member"]
        dst = ["*"]
        ip  = ["*"]
      },
      {
        # kubectl through the operator's API server proxy, as cluster-admin.
        src = ["autogroup:admin"]
        dst = ["tag:k8s-operator"]
        app = {
          "tailscale.com/cap/kubernetes" = [{ impersonate = { groups = ["system:masters"] } }]
        }
      },
    ]

    ssh = [
      {
        # Tailscale's default: SSH into devices you own, re-authenticating first.
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
    ]

    # Checked by Tailscale on every save; a failing test rejects the policy.
    # (Tests can't use autogroups as src, so there is no "admins can reach" test.)
    tests = [
      {
        src  = "tag:k8s"
        deny = ["tag:k8s-operator:443", "tag:server:22", "tag:server:8006", "tag:server:445", "tag:k8s:443"]
      },
      {
        src  = "tag:server"
        deny = ["tag:k8s-operator:443", "tag:k8s:443", "tag:server:22"]
      },
    ]
  })
}
