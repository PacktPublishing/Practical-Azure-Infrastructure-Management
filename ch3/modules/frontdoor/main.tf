resource "azurerm_resource_group" "central_rg" {
  name     = var.central_services_resource_group_name
  location = var.central_services_resource_group_location
}

resource "azurerm_cdn_frontdoor_profile" "vm_app_fd_profile" {
  name                = "vm-app-afd-profile"
  resource_group_name = azurerm_resource_group.central_rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_origin_group" "vm_app_origin_group" {
  name                     = "app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.vm_app_fd_profile.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 240
    path                = "/healthProbe"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 16
    successful_samples_required        = 3
  }

}

resource "azurerm_cdn_frontdoor_origin" "eu_ag_origin" {
  name                           = "eu-ag-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.vm_app_origin_group.id
  enabled                        = true
  host_name                      = var.eu_ag_pip
  http_port                      = 80
  weight                         = 1
  priority                       = 1
  certificate_name_check_enabled = false
}
resource "azurerm_cdn_frontdoor_origin" "na_ag_origin" {
  name                           = "na-ag-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.vm_app_origin_group.id
  enabled                        = true
  host_name                      = var.na_ag_pip
  http_port                      = 80
  weight                         = 1
  priority                       = 1
  certificate_name_check_enabled = false
}

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = "app-vm-fd-ep"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.vm_app_fd_profile.id
}

resource "azurerm_cdn_frontdoor_rule_set" "fd_rule_set" {
  name                     = "AppVMRuleSet"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.vm_app_fd_profile.id
}

resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = "app-vm-fd-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.vm_app_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.eu_ag_origin.id, azurerm_cdn_frontdoor_origin.na_ag_origin.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.fd_rule_set.id]
  enabled                       = true
  patterns_to_match             = ["/*"]
  supported_protocols           = ["Http"]
  https_redirect_enabled        = false
  forwarding_protocol           = "MatchRequest"

  cache {
    query_string_caching_behavior = "IgnoreSpecifiedQueryStrings"
    query_strings                 = ["account", "settings"]
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/javascript", "text/xml"]
  }

}