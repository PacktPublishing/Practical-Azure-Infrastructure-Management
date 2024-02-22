data "azurerm_container_app_environment" "existing_ace" {
  name = var.ace_name
  resource_group_name = var.ace_resource_group_name
}

resource "azurerm_container_app" "aca_app" {
  name                         = var.aca_name
  container_app_environment_id = data.azurerm_container_app_environment.existing_ace.id
  resource_group_name          = var.ace_resource_group_name
  revision_mode                = "Single"
  ingress {
    external_enabled = var.container_info.public
    target_port = var.container_info.port
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = var.container_info.name
      image  = var.container_info.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}