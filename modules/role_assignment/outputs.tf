output "resource" {
  description = "Map of role assignment AzAPI resources, keyed by the input map key."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "Map of role assignment resource IDs, keyed by the input map key. (RMFR7 — the primary resource of this submodule is a collection.)"
  value       = { for k, v in azapi_resource.this : k => v.id }
}
