# Integration tests for terraform-azurerm-avm-res-search-searchservice
#
# These tests run against real Azure infrastructure and require Azure
# credentials (e.g. `az login` or federated GitHub OIDC).

variables {
  location = "eastus"
}

# Create a resource group up-front via the AzAPI provider so that the module
# under test has a real parent to deploy into.
run "setup" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  variables {
    location = var.location
  }
}

# Deploy the search service in its simplest form.
run "minimal_search_service" {
  command = apply

  variables {
    location            = var.location
    name                = run.setup.search_service_name
    resource_group_name = run.setup.resource_group_name
    sku                 = "basic"
    tags = {
      environment = "integration-test"
      module      = "avm-res-search-searchservice"
    }
  }

  assert {
    condition     = azapi_resource.this.id != ""
    error_message = "Search service resource ID should be populated after apply."
  }

  assert {
    condition     = azapi_resource.this.body.sku.name == "basic"
    error_message = "SKU should be propagated to the ARM body."
  }

  assert {
    condition     = output.resource_id == azapi_resource.this.id
    error_message = "resource_id output should equal the primary resource ID."
  }
}

# Verify a system-assigned identity is provisioned and the principalId is
# exported.
run "with_system_assigned_identity" {
  command = apply

  variables {
    location            = var.location
    name                = run.setup.search_service_name
    resource_group_name = run.setup.resource_group_name
    sku                 = "basic"

    managed_identities = {
      system_assigned = true
    }

    tags = {
      environment = "integration-test"
    }
  }

  assert {
    condition     = output.system_assigned_principal_id != null && output.system_assigned_principal_id != ""
    error_message = "system_assigned_principal_id output should be populated when system_assigned identity is enabled."
  }
}

# Disable public network access — flip the property and confirm the body.
run "public_network_access_disabled" {
  command = apply

  variables {
    location                      = var.location
    name                          = run.setup.search_service_name
    resource_group_name           = run.setup.resource_group_name
    sku                           = "basic"
    public_network_access_enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.publicNetworkAccess == "Disabled"
    error_message = "publicNetworkAccess should be Disabled in the ARM body."
  }
}
