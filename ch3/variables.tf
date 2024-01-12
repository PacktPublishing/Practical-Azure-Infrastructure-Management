variable "resource_group_location" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  default     = "eu-vm-app-infra-rg"
  description = "Name of the resource group."
}

variable "vmprefix" {
  default     = "euweb01"
  description = "Prefix for all resources."
}