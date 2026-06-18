# TODO: insert locals here.
locals {
  # managed_identities = {
  #   system_assigned_user_assigned = (var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0) ? {
  #     this = {
  #       type                       = var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" : length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : "SystemAssigned"
  #       user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
  #     }
  #   } : {}
  #   system_assigned = var.managed_identities.system_assigned ? {
  #     this = {
  #       type = "SystemAssigned"
  #     }
  #   } : {}
  #   user_assigned = length(var.managed_identities.user_assigned_resource_ids) > 0 ? {
  #     this = {
  #       type                       = "UserAssigned"
  #       user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
  #     }
  #   } : {}
  # }
  # Private endpoint application security group associations
  # We merge the nested maps from private endpoints and application security group associations into a single map.
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  # Parsed Key Vault identifiers used by the CMK PATCH (main.cmk.tf). The data source
  # needs name + resource group; the variable only takes the resource ID for consumer
  # ergonomics and AVM interface consistency.
  cmk_key_vault_resource_id_parts = var.customer_managed_key == null ? null : regex(
    "(?i)^/subscriptions/[^/]+/resourceGroups/(?P<rg>[^/]+)/providers/Microsoft\\.KeyVault/vaults/(?P<name>[^/]+)$",
    var.customer_managed_key.key_vault_resource_id,
  )
  cmk_key_vault_name                = try(local.cmk_key_vault_resource_id_parts.name, null)
  cmk_key_vault_resource_group_name = try(local.cmk_key_vault_resource_id_parts.rg, null)
}
