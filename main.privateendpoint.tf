
# Create private Endpoint
resource "azurerm_private_endpoint" "this" {
  for_each = var.private_endpoints

  location            = coalesce(each.value.location, var.location)
  name                = each.value.name != null ? each.value.name : "pe-${var.name}"
  resource_group_name = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id           = each.value.subnet_resource_id
  tags                = each.value.tags == null ? var.tags : each.value.tags == {} ? {} : each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "psc-${var.name}"
    private_connection_resource_id = azurerm_search_service.this.id
    subresource_names              = ["searchService"]
  }
  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = "searchService"
      subresource_name   = "searchService"
    }
  }
  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = each.value.private_dns_zone_group_name
      private_dns_zone_ids = each.value.private_dns_zone_resource_ids
    }
  }
}
