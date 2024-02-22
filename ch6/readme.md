# Chapter 6

## Create Container Apps environment
```
module "container_env" {
source = "./modules/ace"
 ace_name = "bookaceeu"
 ace_resource_group_name = "ace-infra-eu-rg"
 location = "westeurope"
}
```
## Create Container App with image from a public repository
```
module "public_imaage_aca" {
    source = "./modules/aca"
    aca_name = "iacacapubimg"
    ace_name = module.container_env.ace_name
    ace_resource_group_name = module.container_env.ace_rg_name
    location = "westeurope"
    container_info = {
      image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      name = "picontainer"
      port = 80
      public = true
    }
    depends_on = [ module.container_env ]
}
```
## Create Container Apps Repository
```
module "container_registry" {
    source = "./modules/acr"
    acr_name = "iacbookacr"
    acr_resource_group_name = "iac-book-acr-rg"
    location = "westeurope"
}
```
## Build Container Image and push to ACR

## Deploy Container Apps with image from ACR
