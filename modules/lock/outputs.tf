output "resource" {
  description = "The full `azapi_resource` object representing the lock."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The Azure resource ID of the lock."
  value       = azapi_resource.this.id
}
