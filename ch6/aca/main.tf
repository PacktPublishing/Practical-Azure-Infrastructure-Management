resource "azurerm_container_app" "aca_app" {
  name                         = var.aca_name
  container_app_environment_id = var.ace_id
  resource_group_name          = var.aca_resource_group_name
  revision_mode                = "Single"

  template {
    container {
      name   = var.container_info.name
      image  = var.container_info.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}