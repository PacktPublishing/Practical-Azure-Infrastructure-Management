variable "central_services_resource_group_name" {
  description = "Name of the resource group to host central services."
}
variable "central_services_resource_group_location" {
  description = "Location of the resource group to host central services."
}
variable "eu_ag_pip" {
  description = "Public IP of application gateway in the EU region."
  
}
variable "na_ag_pip" {
  description = "Public IP of application gateway in the NA region."
}