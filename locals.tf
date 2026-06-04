locals {
  # ---------------------------------------------------------------------------
  # Auth options body (only valid when local auth enabled)
  # ---------------------------------------------------------------------------
  auth_options_body = (
    var.local_authentication_enabled == false || var.authentication_failure_mode == null
    ) ? null : {
    aadOrApiKey = {
      aadAuthFailureMode = var.authentication_failure_mode
    }
  }
  # Service-level CMK key configuration is only available on preview API
  # versions of Microsoft.Search/searchServices (2024-06-01-preview onwards
  # at time of writing). On the default stable API only `enforcement` is
  # accepted; consumers wanting full service-level CMK key configuration
  # must override `var.resource_types.search_search_services` to a preview
  # API version.
  cmk_api_supports_service_level_key = can(regex("-preview$", var.resource_types.search_search_services))
  # ---------------------------------------------------------------------------
  # Customer-managed key body
  # ---------------------------------------------------------------------------
  cmk_enforcement = var.customer_managed_key_enforcement_enabled == null ? null : (
    var.customer_managed_key_enforcement_enabled ? "Enabled" : "Disabled"
  )
  cmk_identity_body = var.customer_managed_key == null || var.customer_managed_key.user_assigned_identity == null ? null : {
    "@odata.type"        = "#Microsoft.Azure.Search.DataUserAssignedIdentity"
    userAssignedIdentity = var.customer_managed_key.user_assigned_identity.resource_id
  }
  cmk_service_level_key = (
    var.customer_managed_key == null || !local.cmk_api_supports_service_level_key
    ) ? null : {
    keyVaultUri        = "https://${reverse(split("/", var.customer_managed_key.key_vault_resource_id))[0]}.vault.azure.net"
    keyVaultKeyName    = var.customer_managed_key.key_name
    keyVaultKeyVersion = var.customer_managed_key.key_version
    identity           = local.cmk_identity_body
  }
  encryption_with_cmk_body = (
    local.cmk_enforcement == null && local.cmk_service_level_key == null
    ) ? null : merge(
    local.cmk_enforcement == null ? {} : { enforcement = local.cmk_enforcement },
    local.cmk_service_level_key == null ? {} : { serviceLevelEncryptionKey = local.cmk_service_level_key },
  )
  # ---------------------------------------------------------------------------
  # Hosting mode normalisation (ARM uses TitleCase)
  # ---------------------------------------------------------------------------
  hosting_mode_normalised = var.hosting_mode == null ? null : (
    lower(var.hosting_mode) == "highdensity" ? "HighDensity" : "Default"
  )
  identity_body = local.managed_identity_type == "None" ? null : {
    type = local.managed_identity_type
    userAssignedIdentities = length(var.managed_identities.user_assigned_resource_ids) == 0 ? null : {
      for id in var.managed_identities.user_assigned_resource_ids : id => {}
    }
  }
  # ---------------------------------------------------------------------------
  # Managed identity block for the search service body
  # ---------------------------------------------------------------------------
  managed_identity_type = (
    var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" :
    var.managed_identities.system_assigned ? "SystemAssigned" :
    length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" :
    "None"
  )
  # ---------------------------------------------------------------------------
  # Network rule set body
  # ---------------------------------------------------------------------------
  network_rule_set = {
    bypass  = var.network_rule_bypass_option
    ipRules = var.allowed_ips == null ? [] : [for ip in var.allowed_ips : { value = ip }]
  }
  # ---------------------------------------------------------------------------
  # Flattened ASG associations for private endpoints
  # ---------------------------------------------------------------------------
  private_endpoint_application_security_groups = {
    for pe_k, pe_v in var.private_endpoints : pe_k => [
      for _, asg_id in pe_v.application_security_group_associations : { id = asg_id }
    ]
  }
  # ---------------------------------------------------------------------------
  # Resource group ID (parent_id for top-level resources)
  # ---------------------------------------------------------------------------
  resource_group_resource_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  # Build per-assignment role definition resource IDs.
  # If the input is already a full role definition resource ID, use it as-is;
  # otherwise look it up via the azapi_resource_list data source at subscription scope.
  role_definition_ids = {
    for key, ra in var.role_assignments :
    key => (
      strcontains(lower(ra.role_definition_id_or_name), lower(local.role_definition_resource_substring))
      ? ra.role_definition_id_or_name
      : try(data.azapi_resource_list.role_definitions[0].output.value[
        index([for rd in data.azapi_resource_list.role_definitions[0].output.value : rd.properties.roleName], ra.role_definition_id_or_name)
      ].id, ra.role_definition_id_or_name)
    )
  }
  # ---------------------------------------------------------------------------
  # Role definition substring detection
  # ---------------------------------------------------------------------------
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  # ---------------------------------------------------------------------------
  # Properties body for the search service.
  # Null-valued keys are stripped so we never PUT a null that Azure echoes
  # back as a server default — which would oscillate plans forever.
  # ---------------------------------------------------------------------------
  search_service_properties = { for k, v in {
    authOptions         = local.auth_options_body
    disableLocalAuth    = var.local_authentication_enabled == null ? null : !var.local_authentication_enabled
    encryptionWithCmk   = local.encryption_with_cmk_body
    hostingMode         = local.hosting_mode_normalised
    networkRuleSet      = local.network_rule_set
    partitionCount      = var.partition_count
    publicNetworkAccess = var.public_network_access_enabled ? "Enabled" : "Disabled"
    replicaCount        = var.replica_count
    semanticSearch      = var.semantic_search_sku
  } : k => v if v != null }
}
