output "resource" {
  value       = azapi_resource.this
  description = "Map of diagnostic setting AzAPI resources, keyed by the input map key."
}

output "resource_ids" {
  value       = { for k, v in azapi_resource.this : k => v.id }
  description = "Map of diagnostic setting resource IDs, keyed by the input map key."
}
