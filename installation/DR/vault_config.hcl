api_addr      = "https://dns_of_machine:8200"
cluster_addr  = "https://dns_of_machine:8201"
license_path  = "/opt/vault/config/license.hclic"
disable_mlock = true
ui            = true
 
storage "raft" {
  node_id = "vault-node-1"
  path    = "/opt/vault/data/"
}
 
listener "tcp" {
  tls_disable     = 0
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  tls_cert_file      = "/opt/vault/tls/vault.crt"
  tls_key_file       = "/opt/vault/tls/vault.key"
  tls_client_ca_file = "/opt/vault/tls/vault.ca"

  # Enable unauthenticated metrics access (necessary for Prometheus Operator)
  telemetry {
    unauthenticated_metrics_access = "true"
  }
}
 
log_level = "info"
log_format = "standard"
 
seal "awskms" {
  region = "us-west-2"
}


telemetry {
  prometheus_retention_time = "0h"
  disable_hostname = true
  dogstatsd_addr = "localhost:8125"
  enable_hostname_label = true
}