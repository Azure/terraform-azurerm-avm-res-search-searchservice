# -----------------------------------------------------------------------------
# Cross-provider state migration from the pre-AzAPI module versions.
#
# These `moved` blocks rely on Terraform 1.8+ and the AzAPI provider's
# `MoveResourceState` hook to translate state entries from `azurerm_*`
# addresses to their new `azapi_resource` equivalents (now nested under the
# per-interface submodules per TFRMNFR1) in place — no destroy / re-create.
# They are no-ops once a workspace has already been migrated.
#
# Not every old address can be moved automatically — see the README for the
# residual manual steps (DNS zone group import, ASG association state rm,
# unmanaged-DNS state mv).
# -----------------------------------------------------------------------------

moved {
  from = azurerm_search_service.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this[0]
  to   = module.lock[0].azapi_resource.this
}

moved {
  from = azurerm_role_assignment.this
  to   = module.role_assignment.azapi_resource.this
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = module.diagnostic_setting.azapi_resource.this
}

# The pre-AzAPI module split private endpoints into two resources based on the
# (now removed) `private_endpoints_manage_dns_zone_group` boolean. The default
# (managed) variant is covered here; consumers who set the flag to `false`
# need a one-off `terraform state mv` — see _header.md / README.md.
moved {
  from = azurerm_private_endpoint.this
  to   = module.private_endpoint.azapi_resource.this
}
