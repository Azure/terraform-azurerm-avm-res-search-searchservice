locals {
  avm_azapi_header = "AVM/0.x.x avm-res-search-searchservice/modules/diagnostic_setting"
  parent_name      = reverse(split("/", var.parent_id))[0]
}

resource "azapi_resource" "this" {
  for_each = var.diagnostic_settings

  name      = coalesce(each.value.name, "diag-${local.parent_name}-${each.key}")
  parent_id = var.parent_id
  type      = var.resource_types.insights_diagnostic_settings
  body = {
    properties = { for k, v in {
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
    } : k => v if v != null }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
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
