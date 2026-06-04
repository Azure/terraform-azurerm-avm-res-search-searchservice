output "name" {
  description = "The name of the Azure AI Search Service."
  value       = azapi_resource.this.name
}

output "private_endpoints" {
  description = "A map keyed by `var.private_endpoints` key. Each value is `{ resource_id, dns_zone_group_resource_id, lock_resource_id, role_assignment_resource_ids, resource }` for that PE."
  value = {
    for k, v in module.private_endpoint.resource : k => {
      resource                     = v
      resource_id                  = v.id
      dns_zone_group_resource_id   = try(module.private_endpoint.dns_zone_group_resource_ids[k], null)
      lock_resource_id             = try(module.private_endpoint.lock_resource_ids[k], null)
      role_assignment_resource_ids = { for fk, fid in module.private_endpoint.role_assignment_resource_ids : split("-", fk, )[1] => fid if startswith(fk, "${k}-") }
    }
  }
}

output "resource" {
  description = "The full output for the Azure AI Search Service. This is the `azapi_resource` object including its `output` attribute (exported values from the ARM response)."
  sensitive   = true
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The Azure resource ID of the Search Service."
  value       = azapi_resource.this.id
}

output "system_assigned_principal_id" {
  description = "The principal ID of the Search Service's system-assigned managed identity, if enabled. `null` otherwise."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}
