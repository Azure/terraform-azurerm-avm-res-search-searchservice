# -----------------------------------------------------------------------------
# Subscription / tenant context (used for resource group ID + role lookups)
# -----------------------------------------------------------------------------
data "azapi_client_config" "current" {}

# Look up role definitions at the subscription scope so consumers can supply
# either a full role definition resource ID or a friendly role name.
data "azapi_resource_list" "role_definitions" {
  count = length([for _, ra in var.role_assignments : ra if !strcontains(lower(ra.role_definition_id_or_name), lower(local.role_definition_resource_substring))]) > 0 ? 1 : 0

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
  parent_id = local.resource_group_resource_id
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
# Resource lock (Microsoft.Authorization/locks)
# -----------------------------------------------------------------------------
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.lock.kind
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
# Role assignments (Microsoft.Authorization/roleAssignments)
# -----------------------------------------------------------------------------
resource "random_uuid" "role_assignment" {
  for_each = var.role_assignments
}

resource "azapi_resource" "role_assignment" {
  for_each = var.role_assignments

  name      = random_uuid.role_assignment[each.key].result
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for k, v in {
      roleDefinitionId                   = local.role_definition_ids[each.key]
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
  response_export_values = []
  # When assigning to a freshly-created service principal Azure AD replication
  # may lag; retry on the relevant error message rather than sleeping.
  retry = each.value.skip_service_principal_aad_check ? {
    error_message_regex = concat(
      try(var.retry.error_message_regex, []),
      ["PrincipalNotFound", "does not exist in the directory"]
    )
    interval_seconds     = try(var.retry.interval_seconds, 10)
    max_interval_seconds = try(var.retry.max_interval_seconds, 60)
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
  # (the GUID is carried through state by the `moved` block in main.moved.tf)
  # rather than triggering a destructive replacement.
  lifecycle {
    ignore_changes = [name]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic settings (Microsoft.Insights/diagnosticSettings)
# -----------------------------------------------------------------------------
resource "azapi_resource" "diagnostic_setting" {
  for_each = var.diagnostic_settings

  name      = coalesce(each.value.name, "diag-${var.name}")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.insights_diagnostic_settings
  body = {
    properties = {
      workspaceId                 = each.value.workspace_resource_id
      storageAccountId            = each.value.storage_account_resource_id
      eventHubAuthorizationRuleId = each.value.event_hub_authorization_rule_resource_id
      eventHubName                = each.value.event_hub_name
      marketplacePartnerId        = each.value.marketplace_partner_resource_id
      logAnalyticsDestinationType = each.value.log_analytics_destination_type
      logs = concat(
        [for cat in each.value.log_categories : { category = cat, enabled = true }],
        [for grp in each.value.log_groups : { categoryGroup = grp, enabled = true }],
      )
      metrics = [for cat in each.value.metric_categories : { category = cat, enabled = true }]
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
