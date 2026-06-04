output "private_endpoint_id" {
  description = "The resource ID of the deployed private endpoint."
  value       = module.search_service.private_endpoints["primary"].id
}

output "resource_id" {
  description = "The resource ID of the deployed Search Service."
  value       = module.search_service.resource_id
}
