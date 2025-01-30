<!-- BEGIN_TF_DOCS -->
# Default example

This deploys the module with a private link.

```hcl
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




```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~>4.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~>3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_private_dns_a_record.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) (resource)
- [azurerm_private_dns_zone.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone_virtual_network_link.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_azure_ai_allowed_ips"></a> [azure\_ai\_allowed\_ips](#input\_azure\_ai\_allowed\_ips)

Description: One or more IP Addresses, or CIDR Blocks which should be able to access the AI Search service

Type: `list(string)`

Default: `[]`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_local_authentication_enabled"></a> [local\_authentication\_enabled](#input\_local\_authentication\_enabled)

Description: This variable controls whether or not local authentication is enabled for the module.

Type: `bool`

Default: `true`

### <a name="input_location"></a> [location](#input\_location)

Description: The location for the resources.

Type: `string`

Default: `"westus"`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optinal) A mapping of tags to assign to the resource.

Type: `map(string)`

Default: `null`

## Outputs

The following outputs are exported:

### <a name="output_resource"></a> [resource](#output\_resource)

Description: AI Search resource

## Modules

The following Modules are called:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: ~> 0.3

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: ~> 0.3

### <a name="module_search_service"></a> [search\_service](#module\_search\_service)

Source: ../../

Version:


<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->