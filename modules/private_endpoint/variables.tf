variable "location" {
  type        = string
  description = "(Required) The Azure region where the private endpoints should be deployed."
  nullable    = false
}

variable "private_endpoints" {
  type = map(object({
    name                                    = optional(string, null)
    subnet_resource_id                      = string
    subresource_name                        = string
    parent_id                               = string
    application_security_group_associations = optional(map(string), {})
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
    network_interface_name          = optional(string, null)
    private_dns_zone_group_name     = optional(string, "default")
    private_dns_zone_resource_ids   = optional(set(string), [])
    private_service_connection_name = optional(string, null)
    tags                            = optional(map(string), null)
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    role_assignments = optional(map(object({
      role_definition_resource_id            = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
  default     = {}
  description = "(Required) Map of private endpoints. Keyed by a stable, consumer-chosen identifier."
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.private_endpoints : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", v.subnet_resource_id))])
    error_message = "Each `subnet_resource_id` must be a valid subnet resource ID."
  }

  validation {
    condition     = alltrue([for k, v in var.private_endpoints : can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", v.parent_id))])
    error_message = "Each `parent_id` must be a valid Azure resource group resource ID."
  }
}

variable "private_link_service_resource_id" {
  type        = string
  description = "(Required) The fully-qualified resource ID of the target Azure resource being privately connected to (e.g. the Search Service ID)."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_private_endpoints                         = optional(string, "Microsoft.Network/privateEndpoints@2024-05-01")
    network_private_endpoints_private_dns_zone_groups = optional(string, "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01")
    authorization_locks                               = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                    = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
  })
  default     = {}
  description = "(Optional) Map of ARM resource types and API versions used by this submodule. Per TFFR6."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "(Optional) Whether to include the AVM telemetry User-Agent header on AzAPI requests."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
    multiplier           = optional(number)
    randomization_factor = optional(number)
  })
  default     = null
  description = "(Optional) AzAPI retry configuration. Per TFFR7."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = "(Optional) AzAPI operation timeouts. Per TFFR7."
}
