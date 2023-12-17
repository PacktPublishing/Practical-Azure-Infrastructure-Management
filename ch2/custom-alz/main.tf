
data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "5.0.3"

  default_location = "westeurope"

  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm
    azurerm.management   = azurerm
  }

  root_parent_id = data.azurerm_client_config.core.tenant_id
  root_id        = var.root_id
  root_name      = var.root_name
  library_path   = "${path.root}/lib"

  custom_landing_zones = {
    "${var.root_id}-online-glb" = {
      display_name               = "${upper(var.root_id)} Online Global"
      parent_management_group_id = "${var.root_id}-landing-zones"
      subscription_ids           = []
      archetype_config = {
        archetype_id   = "adp_online"
        parameters     = {}
        access_control = {}
      }
    }
    "${var.root_id}-online-eu" = {
      display_name               = "${upper(var.root_id)} Online EU"
      parent_management_group_id = "${var.root_id}-landing-zones"
      subscription_ids           = []
      archetype_config = {
        archetype_id = "adp_online"
        parameters = {
          Deny-Resource-Locations = {
            listOfAllowedLocations = ["westeurope", ]
          }
          Deny-RSG-Locations = {
            listOfAllowedLocations = ["westeurope", ]
          }
        }
        access_control = {}
      }
    }
  }
}