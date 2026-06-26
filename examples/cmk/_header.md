# Customer-managed key (CMK) example

Deploys a Search Service encrypted at the service level with a customer-managed key (CMK) stored in Azure Key Vault. Uses the Search Service's system-assigned managed identity to access the key.

> [!WARNING]
> Service-level CMK uses the `Microsoft.Search/searchServices@2026-03-01-preview` API. See the root module README for caveats.
