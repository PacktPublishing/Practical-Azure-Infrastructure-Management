# Resource group for Azure Container registry

resource "azurerm_resource_group" "acr_rg" {
    name = var.acr_resource_group_name
    location = var.location
}

resource "azurerm_user_assigned_identity" "umi" {
    name = "umi-${var.acr_name}"
    location = var.location
    resource_group_name = azurerm_resource_group.acr_rg.name
}

# Azure Container Registry for hosting private container images
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.acr_rg.name
  location            = azurerm_resource_group.acr_rg.location
  sku                 = "Premium"
  admin_enabled       = false
  georeplications {
    location                = "East US"
    zone_redundancy_enabled = true
    tags                    = {}
  }
  georeplications {
    location                = "North Europe"
    zone_redundancy_enabled = true
    tags                    = {}
  }
}

# assign AcrPull Role to umi
resource "azurerm_role_assignment" "acr_pull_role" {
  scope              = azurerm_container_registry.acr.id
  role_definition_id = data.azurerm_role_definition.acr_pull.id
  principal_id       = azurerm_user_assigned_identity.umi.principal_id
  principal_type = "ServicePrincipal"
}

data "azurerm_role_definition" "acr_pull" {
  role_definition_id = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
}
