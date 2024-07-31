# required AVM resources interfaces
data "azurerm_resource_group" "parent" {
  count = var.location == null ? 1 : 0

  name = var.resource_group_name
}
# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_search_service.this.id
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_search_service.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_search_service" "this" {
  location                                 = var.location
  name                                     = var.name
  resource_group_name                      = var.resource_group_name
  sku                                      = var.sku
  allowed_ips                              = var.allowed_ips
  authentication_failure_mode              = var.authentication_failure_mode
  customer_managed_key_enforcement_enabled = var.customer_managed_key_enforcement_enabled
  hosting_mode                             = var.hosting_mode
  local_authentication_enabled             = var.local_authentication_enabled
  partition_count                          = var.partition_count
  public_network_access_enabled            = var.public_network_access_enabled
  replica_count                            = var.replica_count
  semantic_search_sku                      = var.semantic_search_sku
  tags                                     = var.tags

  dynamic "identity" {
    for_each = var.managed_identities == {} ? [] : [var.managed_identities]
    content {
      # only SystemAssigned is supported
      type = identity.value.system_assigned ? "SystemAssigned" : null
    }
  }
}
