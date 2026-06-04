# -----------------------------------------------------------------------------
# Private endpoints — composed via the `private_endpoint` submodule per
# TFRMNFR1. The submodule owns the PE itself plus the DNS zone group, the
# per-endpoint management lock, and per-endpoint role assignments. The
# submodule is called exactly once and internally fans out via `for_each` so
# that state addresses remain stable across the AzureRM → AzAPI migration
# (see `main.moved.tf`).
# -----------------------------------------------------------------------------
module "private_endpoint" {
  source = "./modules/private_endpoint"

  location                         = var.location
  private_link_service_resource_id = azapi_resource.this.id
  enable_telemetry                 = var.enable_telemetry
  endpoints = {
    for pe_k, pe_v in var.private_endpoints :
    pe_k => {
      name                                    = pe_v.name
      parent_id                               = local.private_endpoint_parent_ids[pe_k]
      subnet_resource_id                      = pe_v.subnet_resource_id
      subresource_name                        = "searchService"
      network_interface_name                  = pe_v.network_interface_name
      private_service_connection_name         = pe_v.private_service_connection_name
      ip_configurations                       = pe_v.ip_configurations
      application_security_group_associations = pe_v.application_security_group_associations
      private_dns_zone_group_name             = pe_v.private_dns_zone_group_name
      private_dns_zone_resource_ids           = pe_v.private_dns_zone_resource_ids
      lock                                    = pe_v.lock
      tags                                    = pe_v.tags == null ? var.tags : pe_v.tags
      role_assignments = {
        for ra_k, ra_v in pe_v.role_assignments :
        ra_k => {
          role_definition_resource_id            = local.role_definition_resource_ids["${pe_k}-${ra_k}"]
          principal_id                           = ra_v.principal_id
          description                            = ra_v.description
          skip_service_principal_aad_check       = ra_v.skip_service_principal_aad_check
          condition                              = ra_v.condition
          condition_version                      = ra_v.condition_version
          delegated_managed_identity_resource_id = ra_v.delegated_managed_identity_resource_id
          principal_type                         = ra_v.principal_type
        }
      }
    }
  }
  resource_types = {
    network_private_endpoints                         = var.resource_types.network_private_endpoints
    network_private_endpoints_private_dns_zone_groups = var.resource_types.network_private_endpoints_private_dns_zone_groups
    authorization_locks                               = var.resource_types.authorization_locks
    authorization_role_assignments                    = var.resource_types.authorization_role_assignments
  }
  retry    = var.retry
  timeouts = var.timeouts
}
