# OAuth client (scopes: Policy File write, DNS write), SOPS-encrypted in
# credentials.sops.yaml. Ephemeral: decrypted with the local age/PGP key at
# run time, never written to the plan or state.
ephemeral "sops_file" "credentials" {
  source_file = "${path.module}/credentials.sops.yaml"
}

provider "tailscale" {
  tailnet             = "-" # the tailnet the OAuth client belongs to
  oauth_client_id     = ephemeral.sops_file.credentials.data["oauth_client_id"]
  oauth_client_secret = ephemeral.sops_file.credentials.data["oauth_client_secret"]
}
