locals {
  avm_azapi_header = "AVM/0.x.x avm-res-search-searchservice/modules/private_endpoint"
  # PE keys whose DNS zone group should be created.
  dns_zone_group_keys = toset([for k, v in var.endpoints : k if length(v.private_dns_zone_resource_ids) > 0])
  # Per-PE locks (only PEs whose lock is non-null).
  locks       = { for k, v in var.endpoints : k => v.lock if v.lock != null }
  parent_name = reverse(split("/", var.private_link_service_resource_id))[0]
  # Flatten per-PE role assignments into a single map keyed by "<pe_key>-<ra_key>".
  role_assignments_flat = merge([
    for pe_key, pe in var.endpoints : {
      for ra_key, ra in pe.role_assignments :
      "${pe_key}-${ra_key}" => merge(ra, { pe_key = pe_key })
    }
  ]...)
}

resource "azapi_resource" "this" {
  for_each = var.endpoints

  location  = var.location
  name      = coalesce(each.value.name, "pe-${local.parent_name}-${each.key}")
  parent_id = each.value.parent_id
  type      = var.resource_types.network_private_endpoints
  body = {
    properties = {
      subnet = {
        id = each.value.subnet_resource_id
      }
      customNetworkInterfaceName = each.value.network_interface_name
      privateLinkServiceConnections = [
        {
          name = coalesce(each.value.private_service_connection_name, "psc-${local.parent_name}-${each.key}")
          properties = {
            privateLinkServiceId = var.private_link_service_resource_id
            groupIds             = [each.value.subresource_name]
          }
        }
      ]
      ipConfigurations = [
        for _, ipc in each.value.ip_configurations : {
          name = ipc.name
          properties = {
            groupId          = each.value.subresource_name
            memberName       = each.value.subresource_name
            privateIPAddress = ipc.private_ip_address
          }
        }
      ]
      applicationSecurityGroups = [
        for _, asg_id in each.value.application_security_group_associations : { id = asg_id }
      ]
    }
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs = [
    "properties.subnet.id",
  ]
  response_export_values = [
    "properties.networkInterfaces",
    "properties.customDnsConfigs",
  ]
  retry          = var.retry
  tags           = each.value.tags
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

  lifecycle {
    ignore_changes = [
      body.properties.privateLinkServiceConnections[0].properties.requestMessage,
    ]
  }
}

resource "azapi_resource" "dns_zone_group" {
  for_each = local.dns_zone_group_keys

  name      = var.endpoints[each.value].private_dns_zone_group_name
  parent_id = azapi_resource.this[each.value].id
  type      = var.resource_types.network_private_endpoints_private_dns_zone_groups
  body = {
    properties = {
      privateDnsZoneConfigs = [
        for idx, zone_id in tolist(var.endpoints[each.value].private_dns_zone_resource_ids) : {
          name = "config-${idx + 1}"
          properties = {
            privateDnsZoneId = zone_id
          }
        }
      ]
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

resource "azapi_resource" "lock" {
  for_each = local.locks

  name      = coalesce(each.value.name, "lock-${each.value.kind}")
  parent_id = azapi_resource.this[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = each.value.kind
      notes = "Locked by avm-res-search-searchservice/modules/private_endpoint."
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

resource "random_uuid" "role_assignment" {
  for_each = local.role_assignments_flat
}

resource "azapi_resource" "role_assignment" {
  for_each = local.role_assignments_flat

  name      = random_uuid.role_assignment[each.key].result
  parent_id = azapi_resource.this[each.value.pe_key].id
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
  retry = anytrue([for v in values(local.role_assignments_flat) : v.skip_service_principal_aad_check]) ? {
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

  lifecycle {
    ignore_changes = [name]
  }
}
