locals {
  avm_azapi_header = "AVM/0.x.x avm-res-search-searchservice/modules/lock"
}

resource "azapi_resource" "this" {
  name      = coalesce(var.name, "lock-${var.kind}")
  parent_id = var.parent_id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.kind
    }
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
