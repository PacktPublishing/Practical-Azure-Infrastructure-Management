
# Resource group for container apps env and container apps
resource "azurerm_resource_group" "ace_rg" {
  name     = var.ace_resource_group_name
  location = var.location
}

# Container Apps environment
resource "azurerm_container_app_environment" "ace" {
    name = var.ace_name
    location = var.location
    resource_group_name = azurerm_resource_group.ace_rg.name
}
