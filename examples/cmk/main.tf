terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.8.2"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  location = var.location
  name     = module.naming.resource_group.name_unique
}

# Key Vault to host the customer-managed key. RBAC permission model so the
# Search Service's system-assigned identity can be granted "Key Vault Crypto
# Service Encryption User" via a role assignment created after the module call.
resource "azurerm_key_vault" "this" {
  location                      = azurerm_resource_group.this.location
  name                          = module.naming.key_vault.name_unique
  resource_group_name           = azurerm_resource_group.this.name
  sku_name                      = "standard"
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  purge_protection_enabled      = true
}

# Allow the test principal to create keys.
resource "azurerm_role_assignment" "kv_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
}

resource "azurerm_key_vault_key" "cmk" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.search_service.name_unique}-cmk"
  key_size     = 2048

  depends_on = [azurerm_role_assignment.kv_admin]
}

# This is the module call.
module "search_service" {
  source = "../../"

  location                                 = azurerm_resource_group.this.location
  name                                     = module.naming.search_service.name_unique
  resource_group_name                      = azurerm_resource_group.this.name
  customer_managed_key_enforcement_enabled = true
  enable_telemetry                         = var.enable_telemetry
  managed_identities = {
    system_assigned = true
  }
  sku = "standard"

  customer_managed_key = {
    key_vault_resource_id = azurerm_key_vault.this.id
    key_name              = azurerm_key_vault_key.cmk.name
    key_version           = azurerm_key_vault_key.cmk.version
  }
}

# Grant the Search Service's system-assigned identity access to wrap/unwrap the
# CMK. With system-assigned identities the role assignment can only be created
# after the module has provisioned the service, so it lands AFTER the module's
# azapi_update_resource PATCH. In practice Azure validates key access lazily
# (the PATCH returns OK and the service polls encryptionComplianceStatus), so
# this ordering works today. If Azure tightens validation in future, callers
# should switch to a pre-assigned user-assigned identity (tracked in the
# broader azapi refactor).
resource "azurerm_role_assignment" "search_kv" {
  principal_id         = module.search_service.resource.identity[0].principal_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
}
