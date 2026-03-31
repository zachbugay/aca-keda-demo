output "AZURE_CONTAINER_REGISTRY_ENDPOINT" {
  value = azurerm_container_registry.acr.login_server
}

output "AZURE_CONTAINER_REGISTRY_NAME" {
  value = azurerm_container_registry.acr.name
}

output "SERVICE_API_ENDPOINT_URL" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "AZURE_RESOURCE_GROUP" {
  value = azurerm_resource_group.rg.name
}

output "AZURE_LOG_ANALYTICS_WORKSPACE_NAME" {
  value = azurerm_log_analytics_workspace.law.name
}

output "AZURE_LOG_ANALYTICS_WORKSPACE_ID" {
  value = azurerm_log_analytics_workspace.law.workspace_id
}

output "AZURE_CONTAINER_APP_NAME" {
  value = azurerm_container_app.api.name
}
