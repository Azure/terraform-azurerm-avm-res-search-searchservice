# terraform-azurerm-avm-template

This is a template repo for Terraform Azure Verified Modules.

Things to do:

1. Set up a GitHub repo environment called `test`.
1. Configure environment protection rule to ensure that approval is required before deploying to this environment.
1. Create a user-assigned managed identity in your test subscription.
1. Create a role assignment for the managed identity on your test subscription, use the minimum required role.
1. Configure federated identity credentials on the user assigned managed identity. Use the GitHub environment.
1. Search and update TODOs within the code and remove the TODO comments once complete.

## Customer-managed keys (CMK)

> [!WARNING]
> Service-level customer-managed key encryption on Azure AI Search is **only available in the `Microsoft.Search/searchServices@2026-03-01-preview` API**. Per [AVM SFR1](https://azure.github.io/Azure-Verified-Modules/spec/SFR1) the `customer_managed_key` variable is therefore exposed as a preview feature — Microsoft may not provide support for it. Review the [Azure AI Search CMK documentation](https://learn.microsoft.com/azure/search/search-security-manage-encryption-keys) before enabling it.

When `customer_managed_key` is set, the module:

1. Creates the Search Service via `azurerm_search_service` (which uses the stable `2025-05-01` API and has no `serviceLevelEncryptionKey` argument).
2. Issues a follow-up PATCH via `azapi_update_resource` against the `2026-03-01-preview` API to populate `properties.encryptionWithCmk.serviceLevelEncryptionKey`.

There is therefore a brief window between the create call returning and the PATCH applying during which the service is encrypted with Microsoft-managed keys. No search indexes or other encryptable objects exist during that window, so no user data is at rest under the platform key. On subsequent `terraform apply` runs the configuration is idempotent: `azurerm_search_service` uses an older API version that has no knowledge of `serviceLevelEncryptionKey` and so will not revert the CMK to a platform-managed key.

Prerequisites the consumer is responsible for:

- The Search Service must have a managed identity that can access the Key Vault key:
  - If `customer_managed_key.user_assigned_identity` is `null`, the Search Service's system-assigned identity is used. Set `managed_identities.system_assigned = true` (enforced by variable validation).
  - If `customer_managed_key.user_assigned_identity.resource_id` is set, that user-assigned identity is used.
- The identity must be granted `get`, `wrapKey` and `unwrapKey` on the Key Vault key (access policies or the equivalent RBAC role, depending on the Key Vault's permission model).
- Setting `customer_managed_key_enforcement_enabled = true` alongside `customer_managed_key` is recommended so the service rejects non-CMK-encrypted objects.

A broader refactor that replaces `azurerm_search_service` with `azapi_resource` end-to-end (eliminating the brief platform-key window) is tracked separately.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
> 
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
> 
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.
