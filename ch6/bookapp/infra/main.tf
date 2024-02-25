module "private_image_aca" {
  source                  = "../../modules/aca"
  aca_name                = "iacacapriimg"
  ace_name                = "bookaceeu"
  ace_resource_group_name = "ace-infra-eu-rg"
  location                = "westeurope"
  acr_name                = "iacbookacr"
  acr_resource_group_name = "iac-book-acr-rg"
  umi_name                = "umi-iacbookacr"
  container_info = {
    image  = "iacbookacr.azurecr.io/bookapp/demo:v1"
    name   = "pricontainer"
    port   = 80
    public = true
  }
}