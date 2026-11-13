mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Search/searchServices/search-test"
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [
          {
            id         = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/8ebe5a00-799e-43f5-93ac-243d3dce84a7"
            properties = { roleName = "Search Index Data Contributor" }
          }
        ]
      }
    }
  }
}

mock_provider "random" {}

variables {
  location         = "eastus"
  name             = "srch-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  enable_telemetry = false
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
      module.private_endpoint.resource["default"].body.properties.privateLinkServiceConnections[0].properties.groupIds[0] == "searchService" &&
      module.private_endpoint.resource["default"].body.properties.ipConfigurations[0].properties.groupId == "searchService"
    )
    error_message = "Managed-DNS endpoints must preserve the existing Search subresource default."
  }

  assert {
    condition = (
      module.private_endpoint.resource["custom"].body.properties.privateLinkServiceConnections[0].properties.groupIds[0] == "customGroup" &&
      module.private_endpoint.resource["custom"].body.properties.ipConfigurations[0].properties.groupId == "customGroup"
    )
    error_message = "Managed-DNS endpoints must forward the subresource override."
  }
}

run "unmanaged_dns_subresources" {
  command = plan

  variables {
    private_endpoints_manage_dns_zone_group = false
  }

  assert {
    condition = (
      module.private_endpoint.resource["default"].body.properties.privateLinkServiceConnections[0].properties.groupIds[0] == "searchService" &&
      module.private_endpoint.resource["default"].body.properties.ipConfigurations[0].properties.groupId == "searchService"
    )
    error_message = "Unmanaged-DNS endpoints must preserve the existing Search subresource default."
  }

  assert {
    condition = (
      module.private_endpoint.resource["custom"].body.properties.privateLinkServiceConnections[0].properties.groupIds[0] == "customGroup" &&
      module.private_endpoint.resource["custom"].body.properties.ipConfigurations[0].properties.groupId == "customGroup"
    )
    error_message = "Unmanaged-DNS endpoints must forward the subresource override."
  }
}
