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
  name      = "rg-avm-search-default-${random_string.suffix.result}"
  parent_id = "/subscriptions/${coalesce(data.azapi_client_config.current.subscription_id, "00000000-0000-0000-0000-000000000000")}"
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
}

# This is the module call.
module "search_service" {
  source = "../../"

  location         = var.location
  name             = "search-avm-${random_string.suffix.result}"
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
  sku              = "standard"
}
