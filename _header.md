# Azure Verified Module — Azure AI Search Service

## Customer-managed keys (CMK)

> [!WARNING]
> Service-level customer-managed key encryption on Azure AI Search is **only available in preview API versions** of `Microsoft.Search/searchServices` (`2026-03-01-preview` at the time of writing). Per [AVM SFR1](https://azure.github.io/Azure-Verified-Modules/spec/SFR1) the `customer_managed_key` variable is therefore exposed as a preview feature — Microsoft may not provide support for it. Review the [Azure AI Search CMK documentation](https://learn.microsoft.com/azure/search/search-security-manage-encryption-keys) before enabling it.

When `customer_managed_key` is set, the module keeps the primary `azapi_resource` on the stable GA API and applies the entire writable `properties.encryptionWithCmk` block (the `enforcement` policy and the `serviceLevelEncryptionKey`) via a dedicated `azapi_update_resource` pinned to a preview API (`var.resource_types.search_search_services_cmk`, default `Microsoft.Search/searchServices@2026-03-01-preview`). This keeps the primary resource on a stable API ([SFR1](https://azure.github.io/Azure-Verified-Modules/spec/SFR1)) while still configuring the preview-only key.

There is a brief window between the service being created and the PATCH applying during which it is encrypted with Microsoft-managed keys. No search indexes or other encryptable objects exist during that window, so no user data is at rest under the platform key. The configuration is idempotent on subsequent `terraform apply` runs.

Prerequisites the consumer is responsible for:

- The Search Service must have a managed identity that can access the Key Vault key:
  - If `customer_managed_key.user_assigned_identity` is `null`, the Search Service's system-assigned identity is used. Set `managed_identities.system_assigned = true` (enforced by variable validation).
  - If `customer_managed_key.user_assigned_identity.resource_id` is set, that user-assigned identity is used. It must also be one of `managed_identities.user_assigned_resource_ids` (enforced by variable validation).
- The identity must be granted `get`, `wrapKey` and `unwrapKey` on the Key Vault key (e.g. the `Key Vault Crypto Service Encryption User` RBAC role, or an equivalent access policy) **before** the key is applied.
- Setting `customer_managed_key_enforcement_enabled = true` alongside `customer_managed_key` is recommended so the service rejects non-CMK-encrypted objects.

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
> - **Customer-managed keys — no action required.** The `0.3.x` release already applied CMK through a root-level `azapi_update_resource.cmk[0]` PATCH; that address is unchanged, so the state entry is reused with no destroy / re-create. The `0.3.x` `data.azurerm_key_vault.cmk` lookup is removed (the Key Vault URI is now derived from `customer_managed_key.key_vault_resource_id`). The writable `encryptionWithCmk` block (both the `enforcement` policy and the service-level key) is only available on preview API versions, so the PATCH is pinned to `var.resource_types.search_search_services_cmk` (default `Microsoft.Search/searchServices@2026-03-01-preview`) while the primary resource stays on the stable `search_search_services` API ([SFR1](https://azure.github.io/Azure-Verified-Modules/spec/SFR1)). On the first `apply` after upgrade you may see a single in-place PATCH as `enforcement` moves from the search service body onto the CMK update resource.
>   - If you grant the search service's **system-assigned** identity Key Vault access for CMK, note that the principal is now exposed via `output.system_assigned_principal_id` (was `output.resource.identity[0].principal_id`). Because that output is recomputed during the AzureRM→AzAPI state move, any of **your own** resources that reference it (e.g. a Key Vault role assignment) may be recreated with the same principal on the migration `apply`. The search service itself is updated in place — it is never re-created — and the CMK key configuration is preserved throughout. This was verified end-to-end by deploying `0.3.0` with CMK and upgrading in place: the search service migrated with no replacement and the post-upgrade `plan` reported no changes.
> - Output shapes: `output.resource` and `output.private_endpoints` now wrap `azapi_resource` objects rather than `azurerm_search_service` / `azurerm_private_endpoint`. Downstream code should read `output.resource_id` (unchanged) where possible.

This module deploys an **Azure AI Search** service (`Microsoft.Search/searchServices`) along with the standard AVM cross-cutting interfaces it supports: `diagnostic_settings`, `role_assignments`, `lock`, `tags`, `managed_identities` (system- and user-assigned), `private_endpoints`, and `customer_managed_key`.

## Features

- 🔐 **WAF-aligned defaults** — public network access enabled with `bypass = None`; lock and CMK opt-in.
- 🆔 **Full managed identity support** — system-assigned, user-assigned, or both.
- 🔑 **Service-level customer-managed keys** with optional user-assigned identity for Key Vault access.
- 🌐 **Private endpoints** with per-endpoint DNS zone group management.
- 📊 **Diagnostic settings** to Log Analytics, storage, Event Hub or partner solution.
- 🛡️ **AzAPI-first** — built on `Microsoft.Search/searchServices@2025-05-01` (with a preview-API `azapi_update_resource` for customer-managed keys) plus the standard AzAPI interface resources. No AzureRM provider required.

> [!NOTE]
> As the AVM framework is not yet GA, this module is published as a pre-release `0.x.y` version per [SNFR12](https://azure.github.io/Azure-Verified-Modules/spec/SNFR12). Breaking changes may still occur between minor versions.
