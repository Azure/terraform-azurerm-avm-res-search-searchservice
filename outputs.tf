output "name" {
  description = "The name of the Azure AI Search Service."
  value       = azapi_resource.this.name
}

output "private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to `var.private_endpoints`. The map value is the full `azapi_resource` object for the private endpoint."
  value       = azapi_resource.private_endpoint
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
