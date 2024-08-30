output "resource" {
  description = "AI Search resource"
  sensitive   = true
  value       = module.search_service
}
