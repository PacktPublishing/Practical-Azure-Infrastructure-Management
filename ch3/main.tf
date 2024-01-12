module "eu_web_vm" {
  source = "./modules/webvm"
  resource_group_location = "westeurope"
  resource_group_name = "eu-vm-app-infra-rg"
  vmprefix = "euweb01"
}

module "na_web_vm" {
  source = "./modules/webvm"
  resource_group_location = "eastus"
  resource_group_name = "na-vm-app-infra-rg"
  vmprefix = "naweb01"
}

module "global_frontdoor" {
  source = "./modules/frontdoor"
  central_services_resource_group_name = "central-services-rg"
  central_services_resource_group_location = "westeurope"
  eu_ag_pip = module.eu_web_vm.app_gw_pip
  na_ag_pip = module.na_web_vm.app_gw_pip
  depends_on = [ module.eu_web_vm, module.na_web_vm ]
}