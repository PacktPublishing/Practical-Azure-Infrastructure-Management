variable "resource_group_location" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  default     = "vm-app-infra-rg"
  description = "Name of the resource group."
}

variable "vmprefix" {
  default     = "web"
  description = "Prefix for all resources."
}