# Unit tests for terraform-azurerm-avm-res-search-searchservice
#
# All providers are mocked so these tests run without Azure credentials and
# validate module logic (variable shaping, body construction, conditional
# resources, validation rules) at apply time.

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Search/searchServices/search-test"
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [
          {
            id         = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/8ebe5a00-799e-43f5-93ac-243d3dce84a7"
            properties = { roleName = "Search Index Data Contributor" }
          }
        ]
      }
    }
  }
}

mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location            = "eastus"
  name                = "search-unit-test"
  resource_group_name = "rg-unit-test"
}

run "defaults_apply" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Search/searchServices@2025-05-01"
    error_message = "Primary resource MUST use the AzAPI Microsoft.Search/searchServices type from var.resource_types (TFFR6)."
  }

  assert {
    condition     = azapi_resource.this.body.sku.name == "standard"
    error_message = "Default SKU should be 'standard'."
  }

  assert {
    condition     = azapi_resource.this.body.properties.publicNetworkAccess == "Enabled"
    error_message = "publicNetworkAccess should default to Enabled."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkRuleSet.bypass == "None"
    error_message = "networkRuleSet.bypass should default to None."
  }

  assert {
    condition     = azapi_resource.this.body.identity == null
    error_message = "Identity block should be null when no managed identities are requested."
  }

  assert {
    condition     = length(azapi_resource.lock) == 0
    error_message = "Lock resource should not be created when var.lock is null."
  }

  assert {
    condition     = length(azapi_resource.role_assignment) == 0
    error_message = "Role assignment resources should not be created when var.role_assignments is empty."
  }

  assert {
    condition     = length(azapi_resource.diagnostic_setting) == 0
    error_message = "Diagnostic setting resources should not be created when var.diagnostic_settings is empty."
  }

  assert {
    condition     = length(azapi_resource.private_endpoint) == 0
    error_message = "Private endpoint resources should not be created when var.private_endpoints is empty."
  }

  assert {
    condition     = can(modtm_telemetry.telemetry[0])
    error_message = "Telemetry resource should be created when enable_telemetry defaults to true (SFR3)."
  }
}

run "telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry resource MUST NOT be created when enable_telemetry is false."
  }
}

run "managed_identity_system_assigned" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = azapi_resource.this.body.identity.type == "SystemAssigned"
    error_message = "identity.type should be SystemAssigned."
  }

  assert {
    condition     = azapi_resource.this.body.identity.userAssignedIdentities == null
    error_message = "userAssignedIdentities should be null when no user-assigned identities are supplied."
  }
}

run "managed_identity_user_assigned" {
  command = apply

  variables {
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-test"
      ]
    }
  }

  assert {
    condition     = azapi_resource.this.body.identity.type == "UserAssigned"
    error_message = "identity.type should be UserAssigned."
  }

  assert {
    condition     = length(keys(azapi_resource.this.body.identity.userAssignedIdentities)) == 1
    error_message = "userAssignedIdentities should contain exactly one entry."
  }
}

run "managed_identity_both" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-test"
      ]
    }
  }

  assert {
    condition     = azapi_resource.this.body.identity.type == "SystemAssigned, UserAssigned"
    error_message = "identity.type should be 'SystemAssigned, UserAssigned' when both are requested."
  }
}

run "lock_created" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = length(azapi_resource.lock) == 1
    error_message = "Lock resource should be created when var.lock is set."
  }

  assert {
    condition     = azapi_resource.lock[0].type == "Microsoft.Authorization/locks@2020-05-01"
    error_message = "Lock resource MUST use the AzAPI Microsoft.Authorization/locks type from var.resource_types (TFFR6)."
  }

  assert {
    condition     = azapi_resource.lock[0].body.properties.level == "CanNotDelete"
    error_message = "Lock level should be propagated from var.lock.kind."
  }

  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete"
    error_message = "Lock name should default to lock-<kind> when var.lock.name is null."
  }
}

run "diagnostic_settings_created" {
  command = apply

  variables {
    diagnostic_settings = {
      to_law = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.diagnostic_setting) == 1
    error_message = "One diagnostic setting should be created."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["to_law"].type == "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
    error_message = "Diagnostic setting MUST use the AzAPI type from var.resource_types (TFFR6)."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["to_law"].body.properties.workspaceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
    error_message = "workspaceId should be propagated from workspace_resource_id."
  }

  assert {
    condition     = length(azapi_resource.diagnostic_setting["to_law"].body.properties.logs) == 1
    error_message = "Default log_groups = ['allLogs'] should produce one log entry."
  }

  assert {
    condition     = azapi_resource.diagnostic_setting["to_law"].body.properties.logs[0].categoryGroup == "allLogs"
    error_message = "Default log entry should use categoryGroup = allLogs."
  }
}

run "role_assignment_by_name" {
  command = apply

  variables {
    role_assignments = {
      reader = {
        role_definition_id_or_name = "Search Index Data Contributor"
        principal_id               = "00000000-0000-0000-0000-00000000abcd"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.role_assignment) == 1
    error_message = "Role assignment should be created."
  }

  assert {
    condition     = azapi_resource.role_assignment["reader"].type == "Microsoft.Authorization/roleAssignments@2022-04-01"
    error_message = "Role assignment MUST use the AzAPI roleAssignments type from var.resource_types (TFFR6)."
  }

  assert {
    condition     = azapi_resource.role_assignment["reader"].body.properties.principalId == "00000000-0000-0000-0000-00000000abcd"
    error_message = "principalId should be propagated."
  }
}

run "role_assignment_by_id" {
  command = apply

  variables {
    role_assignments = {
      reader = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "00000000-0000-0000-0000-00000000abcd"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignment["reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "When a full role definition ID is supplied, it should be used verbatim."
  }
}

run "private_endpoint_created" {
  command = apply

  variables {
    public_network_access_enabled = false
    private_endpoints = {
      primary = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"]
      }
    }
  }

  assert {
    condition     = length(azapi_resource.private_endpoint) == 1
    error_message = "One private endpoint should be created."
  }

  assert {
    condition     = azapi_resource.private_endpoint["primary"].type == "Microsoft.Network/privateEndpoints@2024-05-01"
    error_message = "Private endpoint MUST use the AzAPI privateEndpoints type from var.resource_types (TFFR6)."
  }

  assert {
    condition     = azapi_resource.private_endpoint["primary"].body.properties.privateLinkServiceConnections[0].properties.groupIds[0] == "searchService"
    error_message = "Private endpoint groupId MUST be 'searchService'."
  }

  assert {
    condition     = length(azapi_resource.private_endpoint_dns_zone_group) == 1
    error_message = "DNS zone group should be created when private_endpoints_manage_dns_zone_group is true (default) and zones are supplied."
  }

  assert {
    condition     = azapi_resource.this.body.properties.publicNetworkAccess == "Disabled"
    error_message = "publicNetworkAccess should be Disabled when public_network_access_enabled is false."
  }
}

run "private_endpoint_unmanaged_dns" {
  command = apply

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      primary = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"]
      }
    }
  }

  assert {
    condition     = length(azapi_resource.private_endpoint_dns_zone_group) == 0
    error_message = "DNS zone group MUST NOT be created when private_endpoints_manage_dns_zone_group is false."
  }
}

run "customer_managed_key" {
  command = apply

  variables {
    # Service-level CMK key config requires a preview API version.
    resource_types = {
      search_search_services = "Microsoft.Search/searchServices@2025-02-01-preview"
    }
    customer_managed_key_enforcement_enabled = true
    customer_managed_key = {
      key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      key_name              = "search-cmk"
      key_version           = "01abcdef"
      user_assigned_identity = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-test"
      }
    }
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-test"
      ]
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.encryptionWithCmk.enforcement == "Enabled"
    error_message = "CMK enforcement should be 'Enabled' when customer_managed_key_enforcement_enabled is true."
  }

  assert {
    condition     = azapi_resource.this.body.properties.encryptionWithCmk.serviceLevelEncryptionKey.keyVaultKeyName == "search-cmk"
    error_message = "keyVaultKeyName should be propagated from customer_managed_key.key_name."
  }

  assert {
    condition     = azapi_resource.this.body.properties.encryptionWithCmk.serviceLevelEncryptionKey.keyVaultUri == "https://kv-test.vault.azure.net"
    error_message = "keyVaultUri should be derived from the Key Vault resource ID."
  }

  assert {
    condition     = azapi_resource.this.body.properties.encryptionWithCmk.serviceLevelEncryptionKey.identity["@odata.type"] == "#Microsoft.Azure.Search.DataUserAssignedIdentity"
    error_message = "CMK identity should be a DataUserAssignedIdentity when a user-assigned identity is supplied."
  }
}

# When using the stable default API version, service-level CMK key config
# is silently dropped (the stable API only accepts enforcement). Verify that
# enforcement still flows through and the key block is omitted.
run "customer_managed_key_stable_api_enforcement_only" {
  command = apply

  variables {
    customer_managed_key_enforcement_enabled = true
    customer_managed_key = {
      key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      key_name              = "search-cmk"
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.encryptionWithCmk.enforcement == "Enabled"
    error_message = "CMK enforcement should flow through even on the stable API."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties.encryptionWithCmk), "serviceLevelEncryptionKey")
    error_message = "serviceLevelEncryptionKey body MUST be omitted on the stable API to satisfy schema validation."
  }
}

run "hosting_mode_normalisation" {
  command = apply

  variables {
    sku          = "standard3"
    hosting_mode = "highDensity"
  }

  assert {
    condition     = azapi_resource.this.body.properties.hostingMode == "HighDensity"
    error_message = "hosting_mode 'highDensity' should be normalised to 'HighDensity' in the ARM body."
  }
}

run "local_authentication_disabled" {
  command = apply

  variables {
    local_authentication_enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.disableLocalAuth == true
    error_message = "disableLocalAuth should be true when local_authentication_enabled is false."
  }
}

run "allowed_ips" {
  command = apply

  variables {
    allowed_ips = ["10.0.0.0/24", "203.0.113.5"]
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.networkRuleSet.ipRules) == 2
    error_message = "Two IP rules should be created from allowed_ips."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkRuleSet.ipRules[0].value == "10.0.0.0/24"
    error_message = "First IP rule value should match the first allowed_ips entry."
  }
}

run "resource_types_overridable" {
  command = apply

  variables {
    resource_types = {
      search_search_services = "Microsoft.Search/searchServices@2025-02-01-preview"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Search/searchServices@2025-02-01-preview"
    error_message = "Consumer override of resource_types.search_search_services MUST be honoured (TFFR6)."
  }
}

run "retry_and_timeouts_overridable" {
  command = apply

  variables {
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 5
      max_interval_seconds = 30
    }
    timeouts = {
      create = "45m"
      delete = "30m"
    }
  }

  assert {
    condition     = azapi_resource.this.retry.interval_seconds == 5
    error_message = "Consumer-supplied retry config MUST be applied to the primary AzAPI resource (TFFR7)."
  }
}

run "invalid_sku_rejected" {
  command = plan

  variables {
    sku = "premium"
  }

  expect_failures = [var.sku]
}

run "invalid_lock_kind_rejected" {
  command = plan

  variables {
    lock = {
      kind = "InvalidKind"
    }
  }

  expect_failures = [var.lock]
}

run "invalid_name_rejected" {
  command = plan

  variables {
    name = "Invalid--Name"
  }

  expect_failures = [var.name]
}

run "invalid_partition_count_rejected" {
  command = plan

  variables {
    partition_count = 5
  }

  expect_failures = [var.partition_count]
}

run "invalid_diagnostic_settings_no_destination" {
  command = plan

  variables {
    diagnostic_settings = {
      bad = {}
    }
  }

  expect_failures = [var.diagnostic_settings]
}
