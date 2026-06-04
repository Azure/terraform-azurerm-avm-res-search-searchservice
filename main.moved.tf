# -----------------------------------------------------------------------------
# Cross-provider state migration from the pre-AzAPI module versions.
#
# These `moved` blocks rely on Terraform 1.8+ and the AzAPI provider's
# `MoveResourceState` hook to translate state entries from `azurerm_*`
# addresses to their `azapi_resource` equivalents in place — no destroy /
# re-create. They are no-ops once a workspace has already been migrated.
#
# Not every old address can be moved automatically (see MIGRATION.md for
# private DNS zone groups and ASG associations).
# -----------------------------------------------------------------------------

moved {
  from = azurerm_search_service.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this[0]
  to   = azapi_resource.lock[0]
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignment
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = azapi_resource.diagnostic_setting
}

# The pre-AzAPI module split private endpoints into two resources based on the
# (now removed) `private_endpoints_manage_dns_zone_group` boolean. The default
# (managed) variant is covered here; consumers who set the flag to `false`
# need a one-off `terraform state mv` — see MIGRATION.md.
moved {
  from = azurerm_private_endpoint.this
  to   = azapi_resource.private_endpoint
}
