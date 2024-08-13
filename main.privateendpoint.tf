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

locals {

  core_services_vnet_subnets = cidrsubnets("10.0.0.0/22", 6, 2, 4, 3)

  name                 = module.naming.search_service.name_unique
  subnet_address_space = [local.core_services_vnet_subnets[3]]
}

#VNET for private endpoint 
resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
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
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

# Create Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${azurerm_virtual_network.this.name}-link"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
}


# Create private Endpoint
resource "azurerm_private_endpoint" "this" {

  location            = azurerm_resource_group.this.location
  name                = "pe-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this.id


  private_service_connection {
    name                           = "psc-${var.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_search_service.this.id # TODO: Replace this dummy resource azurerm_resource_group.TODO with your module resource
    subresource_names              = ["searchService"]
  }
}

resource "azurerm_private_dns_a_record" "this" {
  name                = azurerm_search_service.this.name
  zone_name           = azurerm_private_dns_zone.this.name
  resource_group_name = azurerm_private_dns_zone.this.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.this.private_service_connection[0].private_ip_address]
}
