variable "resource_group_location" {
  description = "Location of the resource group."
}

variable "resource_group_name" {
  description = "Name of the resource group."
}

variable "vmprefix" {
  description = "Prefix for all resources."
}

variable "envName" {
  description = "Environment name."
}

variable "vmcount" {
  description = "Number of VMs to create."
  default = 1
}