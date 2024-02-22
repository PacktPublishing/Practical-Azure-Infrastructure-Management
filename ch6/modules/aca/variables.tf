variable "ace_resource_group_name" {
  description = "Name of the Azure Container Environment resource group"
}
variable "ace_name" {
  description = "resource id of azure container apps environment"
}
variable "location" {
  description = "name of the azure region"
}
variable "aca_name" {
    description = "name of the container app"
}
variable "container_info" {
    type = object({
      image = string
      name = string 
      port = number
      public = bool
    })
}