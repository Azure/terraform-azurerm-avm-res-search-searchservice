variable "parent_id" {
  type        = string
  description = "(Required) The fully-qualified ARM resource ID of the resource the role assignments should be scoped to."
  nullable    = false
}

variable "role_assignments" {
  type = map(object({
    role_definition_resource_id            = string
    principal_id                           = string
    principal_type                         = optional(string)
    description                            = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    delegated_managed_identity_resource_id = optional(string)
    skip_service_principal_aad_check       = optional(bool, false)
  }))
  default     = {}
  description = "(Required) Map of role assignments. Keyed by a stable, consumer-chosen identifier."
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.role_assignments : can(provider::azapi::parse_resource_id("Microsoft.Authorization/roleDefinitions", v.role_definition_resource_id))])
    error_message = "Every `role_definition_resource_id` must be a valid Microsoft.Authorization/roleDefinitions resource ID."
  }
}

variable "resource_types" {
  type = object({
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
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
