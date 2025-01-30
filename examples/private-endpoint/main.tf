terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5.0"
    }
  }
}
provider "azurerm" {
  features {}
}

locals {
  core_services_vnet_subnets = cidrsubnets("10.0.0.0/22", 6, 2, 4, 3)
  # name                 = var.name
  subnet_address_space = [local.core_services_vnet_subnets[3]]
}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.3"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = var.location
  name     = module.naming.resource_group.name_unique
}

#VNET for private endpoint 
resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

#Subnet for private endpoint
resource "azurerm_subnet" "this" {
  address_prefixes                  = local.subnet_address_space
  name                              = "aisearch-subnet"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  private_endpoint_network_policies = "Enabled"
}


# Create Private DNS Zone for Search Service
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.aisearch.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# Create Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${azurerm_virtual_network.this.name}-link"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "search_service" {
  source = "../../"
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  # ...
  location            = azurerm_resource_group.this.location
  name                = module.naming.search_service.name_unique
  resource_group_name = azurerm_resource_group.this.name
  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this.id]
      private_dns_zone_name         = azurerm_private_dns_zone.this.name
      subnet_resource_id            = azurerm_subnet.this.id
    }
  }

  sku                           = "standard"
  public_network_access_enabled = false


  allowed_ips = var.azure_ai_allowed_ips


  local_authentication_enabled = var.local_authentication_enabled
  managed_identities = {
    system_assigned = true
  }
  enable_telemetry = var.enable_telemetry # see variables.tf


}

resource "azurerm_private_dns_a_record" "this" {
  for_each = module.search_service.private_endpoints

  name                = module.search_service.resource.name
  records             = [each.value.private_service_connection[0].private_ip_address]
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  zone_name           = azurerm_private_dns_zone.this.name
  tags                = var.tags
}




