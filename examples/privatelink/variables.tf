variable "azure_ai_allowed_ips" {
  type        = list(string)
  default     = []
  description = "One or more IP Addresses, or CIDR Blocks which should be able to access the AI Search service"
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "local_authentication_enabled" {
  type        = bool
  default     = true
  description = "This variable controls whether or not local authentication is enabled for the module."
}

variable "location" {
  type        = string
  default     = "westus"
  description = "The location for the resources."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "This variable controls whether or not public network access is enabled for the module."
}
