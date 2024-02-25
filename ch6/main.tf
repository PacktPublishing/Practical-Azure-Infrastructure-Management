module "container_env" {
  source                  = "./modules/ace"
  ace_name                = "bookaceeu"
  ace_resource_group_name = "ace-infra-eu-rg"
  location                = "westeurope"
}

module "container_registry" {
  source                  = "./modules/acr"
  acr_name                = "iacbookacr"
  acr_resource_group_name = "iac-book-acr-rg"
  location                = "westeurope"
}
module "public_image_aca" {
  source                  = "./modules/aca"
  aca_name                = "iacacapubimg"
  ace_name                = module.container_env.ace_name
  ace_resource_group_name = module.container_env.ace_rg_name
  location                = "westeurope"
  acr_name                = module.container_registry.acr_name
  acr_resource_group_name = module.container_registry.acr_rg_name
  umi_name                = module.container_registry.umi_name
  container_info = {
    image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    name   = "picontainer"
    port   = 80
    public = true
  }
  depends_on = [module.container_env,
  module.container_registry]
}