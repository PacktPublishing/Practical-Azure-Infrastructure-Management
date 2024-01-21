output "app_gw_pip" {
  value = azurerm_public_ip.ag_public_ip.ip_address
}