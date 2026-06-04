output "resource" {
  description = "Map of private endpoint AzAPI resources, keyed by the input map key."
  value       = azapi_resource.this
}

output "resource_ids" {
  description = "Map of private endpoint resource IDs, keyed by the input map key."
  value       = { for k, v in azapi_resource.this : k => v.id }
}

output "dns_zone_group_resource_ids" {
  description = "Map of private DNS zone group resource IDs, keyed by the private endpoint key. Only PEs with DNS zones supplied are present."
  value       = { for k, v in azapi_resource.dns_zone_group : k => v.id }
}

output "lock_resource_ids" {
  description = "Map of per-private-endpoint lock resource IDs, keyed by the private endpoint key. Only PEs with locks supplied are present."
  value       = { for k, v in azapi_resource.lock : k => v.id }
}

output "role_assignment_resource_ids" {
  description = "Map of per-private-endpoint role assignment resource IDs, keyed by `<pe_key>-<ra_key>`."
  value       = { for k, v in azapi_resource.role_assignment : k => v.id }
}
