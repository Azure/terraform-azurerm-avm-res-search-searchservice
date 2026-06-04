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

variable "location" {
  type    = string
  default = "eastus"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  upper   = false
  special = false
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-avm-search-int-${random_string.suffix.result}"
  parent_id = "/subscriptions/${coalesce(data.azapi_client_config.current.subscription_id, "00000000-0000-0000-0000-000000000000")}"
  location  = var.location
}

output "resource_group_name" {
  value = azapi_resource.resource_group.name
}

output "search_service_name" {
  # Search service names must be 2-60 chars, lowercase alphanumeric and hyphens.
  value = "search-avm-${random_string.suffix.result}"
}
