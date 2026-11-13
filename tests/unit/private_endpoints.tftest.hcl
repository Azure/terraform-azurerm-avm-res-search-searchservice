mock_provider "azurerm" {
  mock_resource "azurerm_search_service" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Search/searchServices/srch-test"
    }
  }
}

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  name                = "srch-test"
  resource_group_name = "rg-test"
  location            = "eastus"
  enable_telemetry    = false
  private_endpoints = {
    default = {
      name               = "pe-default"
      subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"
      ip_configurations = {
        default = {
          name               = "ip-default"
          private_ip_address = "10.0.0.4"
        }
      }
    }
    custom = {
      name               = "pe-custom"
      subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"
      subresource_name   = "customGroup"
      ip_configurations = {
        default = {
          name               = "ip-custom"
          private_ip_address = "10.0.0.5"
        }
      }
    }
  }
}

run "managed_dns_subresources" {
  command = plan

  assert {
    condition = (
      one(one(azurerm_private_endpoint.this["default"].private_service_connection).subresource_names) == "searchService" &&
      one(azurerm_private_endpoint.this["default"].ip_configuration).subresource_name == "searchService" &&
      one(azurerm_private_endpoint.this["default"].ip_configuration).member_name == "searchService"
    )
    error_message = "Managed-DNS endpoints must preserve the existing Search subresource and member defaults."
  }

  assert {
    condition = (
      one(one(azurerm_private_endpoint.this["custom"].private_service_connection).subresource_names) == "customGroup" &&
      one(azurerm_private_endpoint.this["custom"].ip_configuration).subresource_name == "customGroup" &&
      one(azurerm_private_endpoint.this["custom"].ip_configuration).member_name == "searchService"
    )
    error_message = "Managed-DNS endpoints must forward the subresource override without changing the member default."
  }
}

run "unmanaged_dns_subresources" {
  command = plan

  variables {
    private_endpoints_manage_dns_zone_group = false
  }

  assert {
    condition = (
      one(one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["default"].private_service_connection).subresource_names) == "searchService" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["default"].ip_configuration).subresource_name == "searchService" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["default"].ip_configuration).member_name == "default"
    )
    error_message = "Unmanaged-DNS endpoints must preserve the existing Search subresource and member defaults."
  }

  assert {
    condition = (
      one(one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["custom"].private_service_connection).subresource_names) == "customGroup" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["custom"].ip_configuration).subresource_name == "customGroup" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["custom"].ip_configuration).member_name == "default"
    )
    error_message = "Unmanaged-DNS endpoints must forward the subresource override without changing the member default."
  }
}
