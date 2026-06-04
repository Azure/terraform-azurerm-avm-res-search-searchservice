# -----------------------------------------------------------------------------
# Private endpoint (Microsoft.Network/privateEndpoints)
#
# Two variants exist so we can ignore_changes on the privateDnsZoneGroup child
# when the consumer asks the module not to manage it (typical when DNS is
# enforced by Azure Policy).
# -----------------------------------------------------------------------------
locals {
  private_endpoint_locations = {
    for pe_k, pe_v in var.private_endpoints :
    pe_k => coalesce(pe_v.location, var.location)
  }
  private_endpoint_parent_ids = {
    for pe_k, pe_v in var.private_endpoints :
    pe_k => pe_v.resource_group_name == null ? local.resource_group_resource_id : "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${pe_v.resource_group_name}"
  }
}

resource "azapi_resource" "private_endpoint" {
  for_each = var.private_endpoints

  location  = local.private_endpoint_locations[each.key]
  name      = coalesce(each.value.name, "pe-${var.name}")
  parent_id = local.private_endpoint_parent_ids[each.key]
  type      = var.resource_types.network_private_endpoints
  body = {
    properties = {
      subnet = {
        id = each.value.subnet_resource_id
      }
      customNetworkInterfaceName = each.value.network_interface_name
      privateLinkServiceConnections = [
        {
          name = coalesce(each.value.private_service_connection_name, "psc-${var.name}")
          properties = {
            privateLinkServiceId = azapi_resource.this.id
            groupIds             = ["searchService"]
          }
        }
      ]
      ipConfigurations = [
        for _, ipc in each.value.ip_configurations : {
          name = ipc.name
          properties = {
            groupId          = "searchService"
            memberName       = "searchService"
            privateIPAddress = ipc.private_ip_address
          }
        }
      ]
      applicationSecurityGroups = local.private_endpoint_application_security_groups[each.key]
    }
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = [
    "properties.networkInterfaces",
    "properties.customDnsConfigs",
  ]
  retry          = var.retry
  tags           = each.value.tags == null ? var.tags : each.value.tags
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

  # When the consumer chooses not to manage the DNS zone group, ignore any
  # drift on that nested property (it will be set by an external owner such
  # as Azure Policy).
  lifecycle {
    ignore_changes = [
      body.properties.privateLinkServiceConnections[0].properties.requestMessage,
    ]
  }
}

# -----------------------------------------------------------------------------
# Private DNS zone group (managed only when requested)
# -----------------------------------------------------------------------------
resource "azapi_resource" "private_endpoint_dns_zone_group" {
  for_each = {
    for k, v in var.private_endpoints :
    k => v
    if var.private_endpoints_manage_dns_zone_group && length(v.private_dns_zone_resource_ids) > 0
  }

  name      = each.value.private_dns_zone_group_name
  parent_id = azapi_resource.private_endpoint[each.key].id
  type      = var.resource_types.network_private_endpoints_private_dns_zone_groups
  body = {
    properties = {
      privateDnsZoneConfigs = [
        for idx, zone_id in tolist(each.value.private_dns_zone_resource_ids) : {
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
# Per-private-endpoint lock
# -----------------------------------------------------------------------------
resource "azapi_resource" "private_endpoint_lock" {
  for_each = {
    for k, v in var.private_endpoints : k => v if v.lock != null
  }

  name      = coalesce(each.value.lock.name, "lock-${each.value.lock.kind}")
  parent_id = azapi_resource.private_endpoint[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = each.value.lock.kind
      notes = "Lock managed by terraform-azurerm-avm-res-search-searchservice."
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
# Per-private-endpoint role assignments
# -----------------------------------------------------------------------------
locals {
  private_endpoint_role_assignments = merge([
    for pe_k, pe_v in var.private_endpoints : {
      for ra_k, ra_v in pe_v.role_assignments :
      "${pe_k}-${ra_k}" => merge(ra_v, { pe_key = pe_k })
    }
  ]...)
}

resource "random_uuid" "private_endpoint_role_assignment" {
  for_each = local.private_endpoint_role_assignments
}

resource "azapi_resource" "private_endpoint_role_assignment" {
  for_each = local.private_endpoint_role_assignments

  name      = random_uuid.private_endpoint_role_assignment[each.key].result
  parent_id = azapi_resource.private_endpoint[each.value.pe_key].id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for k, v in {
      roleDefinitionId = (
        strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring))
        ? each.value.role_definition_id_or_name
        : try(data.azapi_resource_list.private_endpoint_role_definitions[0].output.value[
          index([for rd in data.azapi_resource_list.private_endpoint_role_definitions[0].output.value : rd.properties.roleName], each.value.role_definition_id_or_name)
        ].id, each.value.role_definition_id_or_name)
      )
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

  # See azapi_resource.role_assignment in main.tf for rationale.
  lifecycle {
    ignore_changes = [name]
  }
}

data "azapi_resource_list" "private_endpoint_role_definitions" {
  count = length([for _, ra in local.private_endpoint_role_assignments : ra if !strcontains(lower(ra.role_definition_id_or_name), lower(local.role_definition_resource_substring))]) > 0 ? 1 : 0

  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = ["value"]
}
