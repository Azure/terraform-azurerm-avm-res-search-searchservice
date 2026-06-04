# Migration guide: AzureRM → AzAPI (v0.x → v0.next)

This release replaces the AzureRM provider with [AzAPI](https://registry.terraform.io/providers/Azure/azapi/latest) per [AVM TFFR3](https://azure.github.io/Azure-Verified-Modules/spec/TFFR3). Most state moves happen automatically via `moved` blocks (Terraform 1.8+); a small number of resources require one-off operator action.

## Automatic state moves (no action required)

The module ships `moved` blocks that translate the following addresses in place — no destroy / re-create, no downtime:

| Pre-AzAPI address                                                          | New address                                |
| -------------------------------------------------------------------------- | ------------------------------------------ |
| `azurerm_search_service.this`                                              | `azapi_resource.this`                      |
| `azurerm_management_lock.this[0]`                                          | `azapi_resource.lock[0]`                   |
| `azurerm_role_assignment.this["<key>"]`                                    | `azapi_resource.role_assignment["<key>"]`  |
| `azurerm_monitor_diagnostic_setting.this["<key>"]`                         | `azapi_resource.diagnostic_setting["<key>"]` |
| `azurerm_private_endpoint.this["<key>"]`                                   | `azapi_resource.private_endpoint["<key>"]` |

> **Requires Terraform 1.8 or newer.** Earlier versions silently ignore cross-resource-type `moved` blocks and will plan destroys.

After upgrading the module reference, run:

```bash
terraform init -upgrade
terraform plan
```

The plan should show `0 to add, 0 to change, 0 to destroy` for the resources above (any diff there is a regression — open an issue).

## Manual steps

### 1. Private DNS zone groups

Pre-AzAPI, the private DNS zone group was an inline `private_dns_zone_group` block on `azurerm_private_endpoint`. It is now its own AzAPI resource (`azapi_resource.private_endpoint_dns_zone_group["<key>"]`). State carries no entry for it, so Terraform will plan a create on the first apply.

The underlying ARM `Microsoft.Network/privateEndpoints/privateDnsZoneGroups/default` object already exists in Azure, so use an `import` block (one per private endpoint that has `private_dns_zone_resource_ids` set):

```hcl
import {
  to = module.search.azapi_resource.private_endpoint_dns_zone_group["<your-pe-key>"]
  id = "<private-endpoint-resource-id>/privateDnsZoneGroups/default"
}
```

Then `terraform apply`. After the import succeeds, delete the `import` block.

### 2. Application security group associations

Pre-AzAPI used a standalone `azurerm_private_endpoint_application_security_group_association` resource. ASGs are now an inline property of the private endpoint body, so there is no replacement resource.

Drop the old state entries (they are idempotent join records; removing them from state does not detach the ASG in Azure):

```bash
terraform state list | Select-String 'application_security_group_association' | ForEach-Object {
  terraform state rm $_
}
```

The next plan will see the ASGs already present in the private endpoint body and produce no diff.

### 3. Removed input variable: `private_endpoints_manage_dns_zone_group`

The old global boolean is gone. DNS zone group management is now per-private-endpoint: include `private_dns_zone_resource_ids = []` on a PE that should be unmanaged. Adjust your `private_endpoints = { … }` map accordingly before the first apply.

If you previously set `private_endpoints_manage_dns_zone_group = false`, your state contains entries under `azurerm_private_endpoint.this_unmanaged_dns_zone_groups[…]` instead of `…this[…]`. Move each one manually before the first `apply`:

```bash
terraform state mv \
  'module.search.azurerm_private_endpoint.this_unmanaged_dns_zone_groups["<key>"]' \
  'module.search.azapi_resource.private_endpoint["<key>"]'
```

(Repeat for every key in your `private_endpoints` map.)

## Alternative: `aztfmigrate`

If you prefer a tool-driven migration over `moved` blocks (for example because you are on Terraform < 1.8, or you want a one-shot conversion that also rewrites your HCL), use Microsoft's [`aztfmigrate`](https://github.com/Azure/aztfmigrate):

```bash
aztfmigrate plan -r azurerm_search_service.this
aztfmigrate apply
```

See the [official guide](https://learn.microsoft.com/azure/developer/terraform/how-to-migrate-between-azurerm-and-azapi) for full options. The address mapping in the table above still applies.

## Verifying

Once migrated, the only resources in state for this module should match the `Resources` section of the [generated `README.md`](./README.md) — all `azapi_resource.*`, plus the `random_uuid` helpers and the `modtm` telemetry resource. If `terraform state list` still shows any `azurerm_*` entries belonging to this module, repeat the manual steps above for them.
