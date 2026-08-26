locals {
  avm_azapi_header = "AVM/0.x.x avm-res-search-searchservice/modules/role_assignment"
}

resource "random_uuid" "this" {
  for_each = var.assignments
}

resource "azapi_resource" "this" {
  for_each = var.assignments

  name      = random_uuid.this[each.key].result
  parent_id = var.parent_id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for k, v in {
      roleDefinitionId                   = each.value.role_definition_resource_id
      principalId                        = each.value.principal_id
      principalType                      = each.value.principal_type
      description                        = each.value.description
      condition                          = each.value.condition
      conditionVersion                   = each.value.condition_version
      delegatedManagedIdentityResourceId = each.value.delegated_managed_identity_resource_id
    } : k => v if v != null }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  # When assigning to a freshly-created service principal Azure AD replication
  # may lag; retry on the relevant error message rather than sleeping.
  retry = anytrue([for v in values(var.assignments) : v.skip_service_principal_aad_check]) ? {
    error_message_regex = concat(
      try(var.retry.error_message_regex, []),
      ["PrincipalNotFound", "does not exist in the directory"]
    )
    interval_seconds     = try(var.retry.interval_seconds, 10)
    max_interval_seconds = try(var.retry.max_interval_seconds, 60)
    multiplier           = try(var.retry.multiplier, null)
    randomization_factor = try(var.retry.randomization_factor, null)
  } : var.retry
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # Role assignment names are server-allocated GUIDs in Azure; we generate one
  # via random_uuid for new resources but ignore changes so that consumers
  # migrating from the pre-AzAPI module versions keep their existing name
  # (the GUID is carried through state by `moved` blocks in the parent module)
  # rather than triggering a destructive replacement.
  lifecycle {
    ignore_changes = [name]
  }
}
