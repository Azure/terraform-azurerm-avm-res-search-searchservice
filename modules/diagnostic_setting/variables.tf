variable "parent_id" {
  type        = string
  description = "(Required) The fully-qualified ARM resource ID of the resource the diagnostic settings apply to."
  nullable    = false
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
    log_analytics_destination_type           = optional(string, "Dedicated")
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
  }))
  default     = {}
  description = "(Required) Map of diagnostic settings. Keyed by a stable, consumer-chosen identifier."
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Each `log_analytics_destination_type` must be one of: Dedicated, AzureDiagnostics."
  }
  validation {
    condition     = alltrue([for k, v in var.diagnostic_settings : v.workspace_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", v.workspace_resource_id))])
    error_message = "Each `workspace_resource_id` must be a valid Log Analytics workspace resource ID, or `null`."
  }
  validation {
    condition     = alltrue([for k, v in var.diagnostic_settings : v.storage_account_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Storage/storageAccounts", v.storage_account_resource_id))])
    error_message = "Each `storage_account_resource_id` must be a valid Storage Account resource ID, or `null`."
  }
  validation {
    condition     = alltrue([for k, v in var.diagnostic_settings : v.event_hub_authorization_rule_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.EventHub/namespaces/authorizationRules", v.event_hub_authorization_rule_resource_id))])
    error_message = "Each `event_hub_authorization_rule_resource_id` must be a valid Event Hub authorization rule resource ID, or `null`."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "(Optional) Whether to include the AVM telemetry User-Agent header on AzAPI requests."
  nullable    = false
}

variable "resource_types" {
  type = object({
    insights_diagnostic_settings = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
  })
  default     = {}
  description = "(Optional) Map of ARM resource types and API versions used by this submodule. Per TFFR6."
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
