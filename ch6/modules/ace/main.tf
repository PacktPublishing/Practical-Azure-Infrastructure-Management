
# Resource group for container apps env and container apps
resource "azurerm_resource_group" "ace_rg" {
  name     = var.ace_resource_group_name
  location = var.location
}

# Create a virtual network and subnet
resource "azurerm_virtual_network" "ace_infra_vnet" {
  name                = "${var.ace_name}-vnet"
  address_space       = ["10.3.0.0/16"]
  location            = azurerm_resource_group.ace_rg.location
  resource_group_name = azurerm_resource_group.ace_rg.name
}

resource "azurerm_subnet" "ace_web_subnet" {
  name                 = "${var.ace_name}-web-subnet"
  resource_group_name  = azurerm_resource_group.ace_rg.name
  virtual_network_name = azurerm_virtual_network.ace_infra_vnet.name
  address_prefixes     = ["10.3.0.0/21"]
}

# Container Apps environment
resource "azurerm_container_app_environment" "ace" {
  name                     = var.ace_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.ace_rg.name
  infrastructure_subnet_id = azurerm_subnet.ace_web_subnet.id
}

output "ace_name" {
  value = azurerm_container_app_environment.ace.name
}
output "ace_rg_name" {
  value = azurerm_resource_group.ace_rg.name
}