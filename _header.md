# Azure Verified Module — Azure AI Search Service

> [!IMPORTANT]
> **Breaking change — AzAPI migration.** Starting with the next minor release, this module is built on the [AzAPI provider](https://registry.terraform.io/providers/Azure/azapi/latest) per the AVM [TFFR3](https://azure.github.io/Azure-Verified-Modules/spec/TFFR3) AzAPI-first rule. The `azurerm` provider is no longer required.
>
> The module ships [`moved` blocks](./main.moved.tf) (Terraform 1.8+) that translate existing state in place — no destroy / re-create — for the search service, lock, role assignments, diagnostic settings, and the default (managed-DNS) private endpoint variant. After `terraform init -upgrade`, `terraform plan` should report `0 to add, 0 to change, 0 to destroy` for those resources.
>
> Three residual cases need a one-off manual step:
>
> 1. **Replace `resource_group_name` / `location` with `parent_id`.** Per [TFRMFR1](https://azure.github.io/Azure-Verified-Modules/spec/TFRMFR1), the module now takes a single `parent_id` string (the fully-qualified resource ID of the parent resource group). `location` remains a separate input, but the `resource_group_name` input has been removed. Update your module call:
>    ```diff
>     module "search" {
>       source              = "Azure/avm-res-search-searchservice/azurerm"
>       location            = "eastus"
>       name                = "my-search"
>    -  resource_group_name = "my-rg"
>    +  parent_id           = "/subscriptions/.../resourceGroups/my-rg"
>     }
>    ```
> 2. **Private DNS zone groups.** Pre-AzAPI these were an inline block on `azurerm_private_endpoint`; they are now a standalone `azapi_resource.private_endpoint_dns_zone_group["<key>"]`. Add a temporary `import` block per affected PE before the first `apply`:
>    ```hcl
>    import {
>      to = module.search.azapi_resource.private_endpoint_dns_zone_group["<pe-key>"]
>      id = "<private-endpoint-resource-id>/privateDnsZoneGroups/default"
>    }
>    ```
> 3. **ASG associations.** The standalone `azurerm_private_endpoint_application_security_group_association` resource is gone — ASGs are now inline on the PE body. Drop the old state entries (they are idempotent joins; the Azure-side association is untouched): `terraform state rm 'module.search.azurerm_private_endpoint_application_security_group_association.this["<key>"]'`.
> 4. **Removed input `private_endpoints_manage_dns_zone_group`.** DNS zone group management is now per-PE: set `private_dns_zone_resource_ids = []` on a PE that should be unmanaged. Consumers who previously had this flag set to `false` must also `terraform state mv 'module.search.azurerm_private_endpoint.this_unmanaged_dns_zone_groups["<key>"]' 'module.search.azapi_resource.private_endpoint["<key>"]'` per PE before the first plan.
>
> For Terraform < 1.8 or for a tool-driven migration that also rewrites HCL, use [`aztfmigrate`](https://learn.microsoft.com/azure/developer/terraform/how-to-migrate-between-azurerm-and-azapi).
>
> Other notes:
>
> - New `parent_id` variable ([TFRMFR1](https://azure.github.io/Azure-Verified-Modules/spec/TFRMFR1)) replaces `resource_group_name`. The `location` input is unchanged.
> - New `resource_types`, `retry`, and `timeouts` variables ([TFFR6](https://azure.github.io/Azure-Verified-Modules/spec/TFFR6), [TFFR7](https://azure.github.io/Azure-Verified-Modules/spec/TFFR7)) — all default sensibly, no input changes required for typical usage.
> - Output shapes: `output.resource` and `output.private_endpoints` now wrap `azapi_resource` objects rather than `azurerm_search_service` / `azurerm_private_endpoint`. Downstream code should read `output.resource_id` (unchanged) where possible.

This module deploys an **Azure AI Search** service (`Microsoft.Search/searchServices`) along with the standard AVM cross-cutting interfaces it supports: `diagnostic_settings`, `role_assignments`, `lock`, `tags`, `managed_identities` (system- and user-assigned), `private_endpoints`, and `customer_managed_key`.

## Features

- 🔐 **WAF-aligned defaults** — public network access enabled with `bypass = None`; lock and CMK opt-in.
- 🆔 **Full managed identity support** — system-assigned, user-assigned, or both.
- 🔑 **Service-level customer-managed keys** with optional user-assigned identity for Key Vault access.
- 🌐 **Private endpoints** with per-endpoint DNS zone group management.
- 📊 **Diagnostic settings** to Log Analytics, storage, Event Hub or partner solution.
- 🛡️ **AzAPI-first** — built entirely on `Microsoft.Search/searchServices@2025-05-01` plus the standard AzAPI interface resources. No AzureRM provider required.

> [!NOTE]
> As the AVM framework is not yet GA, this module is published as a pre-release `0.x.y` version per [SNFR12](https://azure.github.io/Azure-Verified-Modules/spec/SNFR12). Breaking changes may still occur between minor versions.
