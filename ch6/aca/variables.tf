variable "aca_resource_group_name" {
  description = "Name of the resource group"
}
variable "location" {
  description = "name of the azure region"
}
variable "aca_name" {
    description = "name of the container app"
}
variable "ace_id" {
  description = "resource id of azure container apps environment"
}
variable "container_info" {
    type = object({
      image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      name = string 
    })
}