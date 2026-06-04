variable "kind" {
  type        = string
  description = "(Required) The type of lock. Possible values are `CanNotDelete` and `ReadOnly`."
  nullable    = false

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.kind)
    error_message = "`kind` must be one of: CanNotDelete, ReadOnly."
  }
}

variable "parent_id" {
  type        = string
  description = "(Required) The fully-qualified ARM resource ID of the resource the lock should be applied to."
  nullable    = false
}

variable "resource_types" {
  type = object({
    authorization_locks = optional(string, "Microsoft.Authorization/locks@2020-05-01")
  })
  default     = {}
  description = "(Optional) Map of ARM resource types and API versions used by this submodule. Per TFFR6."
  nullable    = false
}

variable "name" {
  type        = string
  default     = null
  description = "(Optional) The name of the lock. If unset, a name is generated based on `kind`."
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
