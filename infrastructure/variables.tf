variable "doppler_token" {
  description = "Doppler service token for the k8s-codeup/dev config. Read by External Secrets Operator via the doppler-token-auth-api Secret. Set via the TF_VAR_doppler_token env var; backed by the DOPPLER_TOKEN GitHub Actions secret."
  type        = string
  sensitive   = true
}
