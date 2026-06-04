terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

locals {
  pe_subnet_prefix   = cidrsubnet(local.vnet_address_space, 4, 0)
  vnet_address_space = "10.0.0.0/22"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location  = var.location
  name      = "rg-avm-search-pe-${random_string.suffix.result}"
  parent_id = "/subscriptions/${coalesce(data.azapi_client_config.current.subscription_id, "00000000-0000-0000-0000-000000000000")}"
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
}

resource "azapi_resource" "virtual_network" {
  location  = var.location
  name      = "vnet-avm-search-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = [local.vnet_address_space]
      }
      subnets = [
        {
          name = "snet-aisearch-pe"
          properties = {
            addressPrefixes                = [local.pe_subnet_prefix]
            privateEndpointNetworkPolicies = "Enabled"
          }
        }
      ]
    }
  }
  response_export_values = ["properties.subnets"]
  tags                   = var.tags
}

resource "azapi_resource" "private_dns_zone" {
  location  = "global"
  name      = "privatelink.search.windows.net"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/privateDnsZones@2024-06-01"
  body = {
    properties = {}
  }
  tags = var.tags
}

resource "azapi_resource" "private_dns_zone_link" {
  location  = "global"
  name      = "${azapi_resource.virtual_network.name}-link"
  parent_id = azapi_resource.private_dns_zone.id
  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01"
  body = {
    properties = {
      registrationEnabled = false
      virtualNetwork = {
        id = azapi_resource.virtual_network.id
      }
    }
  }
  tags = var.tags
}

module "search_service" {
  source = "../../"

  location                     = var.location
  name                         = "search-avm-${random_string.suffix.result}"
  resource_group_name          = azapi_resource.resource_group.name
  allowed_ips                  = var.azure_ai_allowed_ips
  enable_telemetry             = var.enable_telemetry
  local_authentication_enabled = var.local_authentication_enabled
  managed_identities = {
    system_assigned = true
  }
  private_endpoints = {
    primary = {
      subnet_resource_id            = azapi_resource.virtual_network.output.properties.subnets[0].id
      private_dns_zone_resource_ids = [azapi_resource.private_dns_zone.id]
      private_dns_zone_group_name   = "default"
    }
  }
  public_network_access_enabled = false
  sku                           = "standard"
}
