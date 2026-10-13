variable "location" {
  type        = string
  description = "(Required) Azure region where the resource should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "(Required) The name of the Azure AI Search Service. Must be 2-60 characters, lowercase letters, digits, and hyphens; cannot start or end with a hyphen and cannot contain consecutive hyphens."
  nullable    = false

  validation {
    condition     = var.name == null ? true : (length(var.name) >= 2 && length(var.name) <= 60 && can(regex("^[a-z0-9][a-z0-9]+(-[a-z0-9]+)*$", var.name)))
    error_message = "The name must be 2-60 characters, contain only lowercase letters, digits and hyphens, start with a letter or digit and not contain consecutive hyphens."
  }
}

variable "parent_id" {
  type        = string
  description = <<DESCRIPTION
(Required) The fully-qualified ARM resource ID of the resource group into which the Search Service will be deployed. Example: `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg`.

This module does not create the resource group. The consumer (or composing pattern module) is responsible for providing a `parent_id` for an existing resource group.
DESCRIPTION
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid Azure resource group resource ID."
  }
}

variable "allowed_ips" {
  type        = list(string)
  default     = null
  description = "(Optional) One or more IPv4 addresses or CIDR blocks which should be able to access the Search Service. Maps to `properties.networkRuleSet.ipRules`. Only applied when `public_network_access_enabled` is `true`."
}

variable "authentication_failure_mode" {
  type        = string
  default     = null
  description = "(Optional) The response that the Search Service should return for requests that fail authentication. Possible values are `http401WithBearerChallenge` or `http403`. Maps to `properties.authOptions.aadOrApiKey.aadAuthFailureMode`."

  validation {
    condition     = var.authentication_failure_mode == null ? true : contains(["http401WithBearerChallenge", "http403"], var.authentication_failure_mode)
    error_message = "authentication_failure_mode must be one of: http401WithBearerChallenge, http403."
  }
}

variable "customer_managed_key" {
  type = object({
    key_vault_resource_id = string
    key_name              = string
    key_version           = optional(string, null)
    user_assigned_identity = optional(object({
      resource_id = string
    }), null)
  })
  default     = null
  description = <<DESCRIPTION
THIS IS A VARIABLE USED FOR A PREVIEW SERVICE/FEATURE, MICROSOFT MAY NOT PROVIDE SUPPORT FOR THIS, PLEASE CHECK THE PRODUCT DOCS FOR CLARIFICATION.

(Optional) A customer-managed key configuration to associate with the Search Service. Maps to `properties.encryptionWithCmk.serviceLevelEncryptionKey`.

The Search Service must be able to authenticate to the Key Vault to use the key: either pass a `user_assigned_identity` (which must also be one of `managed_identities.user_assigned_resource_ids`) or enable `managed_identities.system_assigned = true`. Granting that identity access to the Key Vault (e.g. the `Key Vault Crypto Service Encryption User` role) is the consumer's responsibility and must be in place before the key is applied.

> [!NOTE]
> The writable `encryptionWithCmk` block is only available on preview API versions of `Microsoft.Search/searchServices`, so the module applies it through a dedicated `azapi_update_resource` pinned to `var.resource_types.search_search_services_cmk` (default `2026-03-01-preview`) while the primary resource stays on the stable API.

- `key_vault_resource_id` - (Required) The Azure resource ID of the Key Vault containing the key.
- `key_name`              - (Required) The name of the key in the Key Vault.
- `key_version`           - (Optional) The version of the key. If `null`, the latest version is used.
- `user_assigned_identity` - (Optional) The user-assigned identity to use when accessing the Key Vault. If `null`, the Search Service system-assigned identity is used. Must be one of the identities passed via `managed_identities.user_assigned_resource_ids`.
  - `resource_id` - (Required) The resource ID of the user-assigned managed identity.
DESCRIPTION

  validation {
    condition     = var.customer_managed_key == null || can(provider::azapi::parse_resource_id("Microsoft.KeyVault/vaults", try(var.customer_managed_key.key_vault_resource_id, "")))
    error_message = "`customer_managed_key.key_vault_resource_id` must be a valid Azure Key Vault resource ID."
  }
  validation {
    condition     = try(var.customer_managed_key.user_assigned_identity, null) == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", try(var.customer_managed_key.user_assigned_identity.resource_id, "")))
    error_message = "`customer_managed_key.user_assigned_identity.resource_id` must be a valid user-assigned managed identity resource ID."
  }
  validation {
    condition     = try(var.customer_managed_key.user_assigned_identity, null) == null || contains(var.managed_identities.user_assigned_resource_ids, try(var.customer_managed_key.user_assigned_identity.resource_id, ""))
    error_message = "`customer_managed_key.user_assigned_identity.resource_id` must be one of `managed_identities.user_assigned_resource_ids` so the identity is actually assigned to the Search Service."
  }
  validation {
    condition     = var.customer_managed_key == null || var.customer_managed_key.user_assigned_identity != null || var.managed_identities.system_assigned
    error_message = "When `customer_managed_key` is set without `user_assigned_identity`, `managed_identities.system_assigned` must be `true` so the Search Service can authenticate to Key Vault."
  }
  validation {
    condition     = var.customer_managed_key == null || can(regex("-preview$", var.resource_types.search_search_services_cmk))
    error_message = "`resource_types.search_search_services_cmk` must be a `-preview` API version because the writable `encryptionWithCmk.serviceLevelEncryptionKey` is only available on preview versions of `Microsoft.Search/searchServices`."
  }
}

variable "customer_managed_key_enforcement_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Whether the Search Service should enforce that all dependent resources are encrypted with the customer-managed key. Maps to `properties.encryptionWithCmk.enforcement` (`Enabled`/`Disabled`). Applied via the dedicated preview-API `azapi_update_resource` (see `customer_managed_key`)."
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Search Service. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set.
- `log_categories` - (Optional) A set of log categories to send to the destination. Defaults to `[]`.
- `log_groups` - (Optional) A set of log category groups to send to the destination. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the destination. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the Log Analytics workspace.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the Event Hub authorization rule.
- `event_hub_name` - (Optional) The Event Hub name. If unset, the default Event Hub is used.
- `marketplace_partner_resource_id` - (Optional) The resource ID of the Marketplace partner solution.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "log_analytics_destination_type must be one of: Dedicated, AzureDiagnostics."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
    ])
    error_message = "At least one of workspace_resource_id, storage_account_resource_id, event_hub_authorization_rule_resource_id, or marketplace_partner_resource_id must be set."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", v.workspace_resource_id))
    ])
    error_message = "Each `diagnostic_settings[*].workspace_resource_id` must be a valid Log Analytics workspace resource ID, or `null`."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.storage_account_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Storage/storageAccounts", v.storage_account_resource_id))
    ])
    error_message = "Each `diagnostic_settings[*].storage_account_resource_id` must be a valid Storage Account resource ID, or `null`."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.event_hub_authorization_rule_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.EventHub/namespaces/authorizationRules", v.event_hub_authorization_rule_resource_id))
    ])
    error_message = "Each `diagnostic_settings[*].event_hub_authorization_rule_resource_id` must be a valid Event Hub authorization rule resource ID, or `null`."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "hosting_mode" {
  type        = string
  default     = null
  description = "(Optional) Hosting mode for the Search Service. Possible values are `default` or `highDensity` (only valid for the `standard3` SKU). Maps to `properties.hostingMode`. Changing this forces a new resource to be created."

  validation {
    condition     = var.hosting_mode == null ? true : contains(["default", "highDensity", "Default", "HighDensity"], var.hosting_mode)
    error_message = "hosting_mode must be one of: default, highDensity."
  }
}

variable "local_authentication_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Whether the Search Service permits authenticating with API keys. Maps to `properties.disableLocalAuth` (inverted). Defaults to `true` on the service when unset."
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the resource lock applied to the Search Service. Implemented via `Microsoft.Authorization/locks`.

- `kind` - (Required) The type of lock. Possible values are `CanNotDelete` and `ReadOnly`.
- `name` - (Optional) The name of the lock. If not specified, a name is generated based on `kind`.
DESCRIPTION

  validation {
    condition     = var.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], var.lock.kind)
    error_message = "lock.kind must be one of: CanNotDelete, ReadOnly."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on the Search Service.

- `system_assigned` - (Optional) Whether the system-assigned managed identity should be enabled.
- `user_assigned_resource_ids` - (Optional) A set of user-assigned managed identity resource IDs to assign.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in try(var.managed_identities.user_assigned_resource_ids, []) :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "network_rule_bypass_option" {
  type        = string
  default     = "None"
  description = "(Optional) Whether to allow trusted Azure services to bypass network rules. Possible values are `None`, `AzureServices`, and `AzurePortal`. Defaults to `None`. Maps to `properties.networkRuleSet.bypass`."

  validation {
    condition     = contains(["None", "AzureServices", "AzurePortal"], var.network_rule_bypass_option)
    error_message = "network_rule_bypass_option must be one of: None, AzureServices, AzurePortal."
  }
}

variable "partition_count" {
  type        = number
  default     = 1
  description = "(Optional) The number of partitions in the Search Service. Allowed values: 1, 2, 3, 4, 6, 12. Values greater than 1 require a standard SKU."

  validation {
    condition     = contains([1, 2, 3, 4, 6, 12], var.partition_count)
    error_message = "partition_count must be one of: 1, 2, 3, 4, 6, 12."
  }
}

variable "private_endpoints" {
  type = map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on the Search Service. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) Private endpoint name. One is generated if unset.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. Same shape as `var.role_assignments`.
- `lock` - (Optional) A lock to apply to the private endpoint.
- `tags` - (Optional) Tags to assign to the private endpoint.
- `subnet_resource_id` - (Required) The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. Defaults to `default`.
- `private_dns_zone_resource_ids` - (Optional) A set of private DNS zone resource IDs to associate. If empty, no zone group is created.
- `application_security_group_associations` - (Optional) A map (arbitrary key → ASG resource ID) of application security groups to associate.
- `private_service_connection_name` - (Optional) Private service connection name. One is generated if unset.
- `network_interface_name` - (Optional) The custom network interface name. One is generated by Azure if unset.
- `location` - (Optional) The location to deploy the private endpoint in. Defaults to `var.location`.
- `resource_group_name` - (Optional) The name of the resource group to deploy the private endpoint in. Defaults to the resource group of the parent (i.e. the resource group derived from `var.parent_id`).
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint.
  - `name` - (Required) The IP configuration name.
  - `private_ip_address` - (Required) The static private IP address to assign.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.private_endpoints :
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", v.subnet_resource_id))
    ])
    error_message = "Each `private_endpoints[*].subnet_resource_id` must be a valid subnet resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.private_endpoints : [
        for id in v.private_dns_zone_resource_ids :
        can(provider::azapi::parse_resource_id("Microsoft.Network/privateDnsZones", id))
      ]
    ]))
    error_message = "Each entry in `private_endpoints[*].private_dns_zone_resource_ids` must be a valid Private DNS Zone resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.private_endpoints : [
        for _, id in v.application_security_group_associations :
        can(provider::azapi::parse_resource_id("Microsoft.Network/applicationSecurityGroups", id))
      ]
    ]))
    error_message = "Each value in `private_endpoints[*].application_security_group_associations` must be a valid Application Security Group resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.private_endpoints : [
        for _, ra in v.role_assignments :
        ra.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", ra.delegated_managed_identity_resource_id))
      ]
    ]))
    error_message = "Each `private_endpoints[*].role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or `null`."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Whether public network access is enabled. Maps to `properties.publicNetworkAccess` (`Enabled`/`Disabled`)."
}

variable "replica_count" {
  type        = number
  default     = 1
  description = "(Optional) The number of replicas. 1–12 for standard SKUs, 1–3 for basic. At least 2 replicas are required for HA query workloads, 3 for HA indexing."

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 12
    error_message = "replica_count must be between 1 and 12."
  }
}

variable "resource_types" {
  type = object({
    search_search_services                            = optional(string, "Microsoft.Search/searchServices@2025-05-01")
    search_search_services_cmk                        = optional(string, "Microsoft.Search/searchServices@2026-03-01-preview")
    authorization_locks                               = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                    = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings                      = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
    network_private_endpoints                         = optional(string, "Microsoft.Network/privateEndpoints@2024-05-01")
    network_private_endpoints_private_dns_zone_groups = optional(string, "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Override the AzAPI `type` values used by the module. See [TFFR6](https://azure.github.io/Azure-Verified-Modules/spec/TFFR6). Each key defaults to the latest stable API version the module has been tested against (a preview version is used only where a feature is not yet available on a stable API); override only when you need to pin to a specific API version.

- `search_search_services` - The primary `Microsoft.Search/searchServices` resource.
- `search_search_services_cmk` - THIS IS A VARIABLE USED FOR A PREVIEW SERVICE/FEATURE, MICROSOFT MAY NOT PROVIDE SUPPORT FOR THIS, PLEASE CHECK THE PRODUCT DOCS FOR CLARIFICATION. The preview `Microsoft.Search/searchServices` API version used by the dedicated `azapi_update_resource` that applies `customer_managed_key` / `customer_managed_key_enforcement_enabled`. The writable `properties.encryptionWithCmk` block (the `enforcement` policy and the service-level encryption key) is only available on preview API versions, so this MUST be a `-preview` version. The primary resource stays on the stable `search_search_services` API.
- `authorization_locks` - The lock resource used to implement `var.lock`.
- `authorization_role_assignments` - The role assignment resource used to implement `var.role_assignments`.
- `insights_diagnostic_settings` - The diagnostic setting resource used to implement `var.diagnostic_settings`.
- `network_private_endpoints` - The private endpoint resource used to implement `var.private_endpoints`.
- `network_private_endpoints_private_dns_zone_groups` - The private DNS zone group child resource.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) Regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry>.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the Search Service. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `role_definition_id_or_name` - (Required) The full resource ID or display name of the role definition.
- `principal_id` - (Required) The principal (object) ID of the user, group, service principal or managed identity to assign the role to.
- `description` - (Optional) Description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) When assigning to a freshly created service principal, set to `true`. Implemented in AzAPI by retrying the role assignment until the principal is replicated.
- `condition` - (Optional) ABAC condition.
- `condition_version` - (Optional) Version of the condition syntax. Only `2.0` is supported.
- `delegated_managed_identity_resource_id` - (Optional) Resource ID of the delegated managed identity.
- `principal_type` - (Optional) The type of the principal. One of `User`, `Group`, `ServicePrincipal`, `ForeignGroup`, `Device`.

> Note: when `role_definition_id_or_name` is a name (not a full resource ID) the module resolves it via `Microsoft.Authorization/roleDefinitions` data lookup at the subscription scope.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, ra in var.role_assignments :
      ra.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", ra.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or `null`."
  }
}

variable "semantic_search_sku" {
  type        = string
  default     = null
  description = "(Optional) Semantic search billing plan. Possible values are `disabled`, `free`, or `standard`. Maps to `properties.semanticSearch`."

  validation {
    condition     = var.semantic_search_sku == null ? true : contains(["disabled", "free", "standard"], var.semantic_search_sku)
    error_message = "semantic_search_sku must be one of: disabled, free, standard."
  }
}

variable "sku" {
  type        = string
  default     = "standard"
  description = "(Optional) The pricing tier of the Search Service. Defaults to `standard`. Possible values: `free`, `basic`, `standard`, `standard2`, `standard3`, `storage_optimized_l1`, `storage_optimized_l2`. Changing this forces a new resource."

  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2"], var.sku)
    error_message = "sku must be one of: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags to apply to the Search Service."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Values are Go duration strings (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
