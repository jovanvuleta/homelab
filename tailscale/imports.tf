# Adopt the tailnet's existing settings instead of creating them.
import {
  to = tailscale_acl.this
  id = "acl"
}

import {
  to = tailscale_dns_configuration.this
  id = "dns_configuration"
}
