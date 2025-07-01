terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }
}
provider "azurerm" {
  features {

  }
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

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "search_service" {
  source = "../../"

  # source             = "Azure/avm-res-search-searchservice/azurerm"
  # ...
  location            = var.location
  name                = module.naming.search_service.name_unique
  resource_group_name = azurerm_resource_group.this.name
  # managed_identities = {
  #   system_assigned = true
  # }
  enable_telemetry = var.enable_telemetry # see variables.tf
  sku              = "standard"
}
