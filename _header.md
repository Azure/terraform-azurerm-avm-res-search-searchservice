# Azure Verified Module — Azure AI Search Service

> [!IMPORTANT]
> **Breaking change — AzAPI migration.** Starting with the next minor release, this module is built on the [AzAPI provider](https://registry.terraform.io/providers/Azure/azapi/latest) per the AVM [TFFR3](https://azure.github.io/Azure-Verified-Modules/spec/TFFR3) AzAPI-first rule. The `azurerm` provider is no longer required. Existing consumers should:
>
> 1. Remove the `azurerm` provider declaration from any root configuration that uses this module standalone.
> 2. Re-plan after upgrading — Terraform will detach state-managed `azurerm_*` resources from the module and (re)attach the equivalent `azapi_resource` resources. Use [`terraform import` with `aztfmigrate`](https://learn.microsoft.com/en-us/azure/developer/terraform/aztfmigrate) to migrate existing state without recreating the Search Service.
> 3. Note the new `resource_types`, `retry` and `timeouts` variables ([TFFR6](https://azure.github.io/Azure-Verified-Modules/spec/TFFR6), [TFFR7](https://azure.github.io/Azure-Verified-Modules/spec/TFFR7)) — all default sensibly so no input changes are required for typical usage.
> 4. Output shapes have changed: `output.resource` and `output.private_endpoints` now wrap `azapi_resource` objects rather than `azurerm_search_service` / `azurerm_private_endpoint`. Downstream code should read `output.resource_id` (unchanged) where possible.

This module deploys an **Azure AI Search** service (`Microsoft.Search/searchServices`) along with the standard AVM cross-cutting interfaces it supports: `diagnostic_settings`, `role_assignments`, `lock`, `tags`, `managed_identities` (system- and user-assigned), `private_endpoints`, and `customer_managed_key`.

## Features

- 🔐 **WAF-aligned defaults** — public network access enabled with `bypass = None`; lock and CMK opt-in.
- 🆔 **Full managed identity support** — system-assigned, user-assigned, or both.
- 🔑 **Service-level customer-managed keys** with optional user-assigned identity for Key Vault access.
- 🌐 **Private endpoints** with optional in-module DNS zone group management (set `private_endpoints_manage_dns_zone_group = false` if DNS is managed by policy).
- 📊 **Diagnostic settings** to Log Analytics, storage, Event Hub or partner solution.
- 🛡️ **AzAPI-first** — built entirely on `Microsoft.Search/searchServices@2025-05-01` plus the standard AzAPI interface resources. No AzureRM provider required.

> [!NOTE]
> As the AVM framework is not yet GA, this module is published as a pre-release `0.x.y` version per [SNFR12](https://azure.github.io/Azure-Verified-Modules/spec/SNFR12). Breaking changes may still occur between minor versions.
