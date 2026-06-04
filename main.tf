# -----------------------------------------------------------------------------
# Subscription / tenant context (used for role definition lookups).
# -----------------------------------------------------------------------------
data "azapi_client_config" "current" {}

# Single subscription-scoped lookup of role definitions, shared between the
# root `role_assignments` variable and any per-private-endpoint role
# assignments. Skipped when every assignment already supplies a full role
# definition resource ID.
data "azapi_resource_list" "role_definitions" {
  count = length(local.role_assignments_requiring_lookup) > 0 ? 1 : 0

  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = ["value"]
}

# -----------------------------------------------------------------------------
# Primary resource: Azure AI Search service
# -----------------------------------------------------------------------------
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.search_search_services
  body = {
    sku = {
      name = var.sku
    }
    identity   = local.identity_body
    properties = local.search_service_properties
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs = [
    "properties.hostingMode",
  ]
  response_export_values = [
    "identity.principalId",
    "identity.tenantId",
    "properties.endpoint",
  ]
  retry = var.retry
  # The AzAPI provider's embedded schema for `Microsoft.Search/searchServices`
  # does not yet recognise the preview `serviceLevelEncryptionKey` field. When
  # the consumer has opted into service-level CMK (which already requires a
  # preview API version via `var.resource_types.search_search_services`) we
  # bypass embedded schema validation; Azure Resource Manager still validates
  # the body server-side.
  schema_validation_enabled = local.cmk_service_level_key == null
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# -----------------------------------------------------------------------------
# Cross-cutting interface submodules (TFRMNFR1).
# -----------------------------------------------------------------------------

module "lock" {
  source = "./modules/lock"
  count  = var.lock == null ? 0 : 1

  parent_id = azapi_resource.this.id
  kind      = var.lock.kind
  name      = var.lock.name
  resource_types = {
    authorization_locks = var.resource_types.authorization_locks
  }
  enable_telemetry = var.enable_telemetry
  retry            = var.retry
  timeouts         = var.timeouts
}

module "role_assignment" {
  source = "./modules/role_assignment"

  parent_id = azapi_resource.this.id
  role_assignments = {
    for k, v in var.role_assignments : k => {
      role_definition_resource_id            = local.role_definition_resource_ids[k]
      principal_id                           = v.principal_id
      principal_type                         = v.principal_type
      description                            = v.description
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      skip_service_principal_aad_check       = v.skip_service_principal_aad_check
    }
  }
  resource_types = {
    authorization_role_assignments = var.resource_types.authorization_role_assignments
  }
  enable_telemetry = var.enable_telemetry
  retry            = var.retry
  timeouts         = var.timeouts
}

module "diagnostic_setting" {
  source = "./modules/diagnostic_setting"

  parent_id           = azapi_resource.this.id
  diagnostic_settings = var.diagnostic_settings
  resource_types = {
    insights_diagnostic_settings = var.resource_types.insights_diagnostic_settings
  }
  enable_telemetry = var.enable_telemetry
  retry            = var.retry
  timeouts         = var.timeouts
}
