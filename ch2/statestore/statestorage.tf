terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "state_rg" {
  name     = "iac-terraform-state-rg"
  location = "West Europe"
}
resource "azurerm_storage_account" "state_store_sa" {
  name                     = "iacbookstate2023"
  resource_group_name      = azurerm_resource_group.state_rg.name
  location                 = azurerm_resource_group.state_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "state_store_container" {
  name                  = "alzcoretfstate"
  storage_account_name  = azurerm_storage_account.state_store_sa.name
  container_access_type = "private"
}