data "azurerm_container_app_environment" "existing_ace" {
  name                = var.ace_name
  resource_group_name = var.ace_resource_group_name
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

data "azurerm_user_assigned_identity" "umi" {
  name                = var.umi_name
  resource_group_name = var.acr_resource_group_name
}

resource "azurerm_container_app" "aca_app" {
  name                         = var.aca_name
  container_app_environment_id = data.azurerm_container_app_environment.existing_ace.id
  resource_group_name          = var.ace_resource_group_name
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.umi.id]
  }
  ingress {
    external_enabled = var.container_info.public
    target_port      = var.container_info.port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.umi.id
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