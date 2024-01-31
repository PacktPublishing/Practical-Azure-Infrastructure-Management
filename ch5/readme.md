# Chapter 5

## Deploy VM with Availability Zone

In the root module main.tf under ch5 directory, place the following module declration to create virtual machine with availability sets

```
module "testvm" {
    source                  = "./modules/webvm"
    resource_group_location = "westeurope"
    resource_group_name     = "eu-vm-app-infra-test-rg"
    vmprefix                = "webvm"
    envName = "p"
    vmcount = 2
}
```

## Deploy VM with Availbility Sets
 To deploy multiple virtual machines with availability sets, update main.tf in root module of ch5 directory as following
 ```
module "testvm" {
    source                  = "./modules/webvm-avset"
    resource_group_location = "westeurope"
    resource_group_name     = "eu-vm-app-infra-test-rg"
    vmprefix                = "webvm"
    envName = "p"
    vmcount = 2
}
```

## Deploy VM with Backup policy

Deploy a azure virtual machine configured with backup policy. Update main.tf in root module of ch5 directory as following

```
module "testvm" {
    source                  = "./modules/webvm-backup"
    resource_group_location = "westeurope"
    resource_group_name     = "eu-vm-app-infra-test-rg"
    vmprefix                = "webvm"
    envName = "p"
    vmcount = 1
}

```
## Deploy Virtual Machine with Disaster Recovery using Azure Recovery Services Vault
```
module "testvm" {
    source                  = "./modules/webvm-dr"
    source_resource_group_location = "eastus"
    source_resource_group_name     = "na-vm-primary-infra-test-rg"
    vmprefix                = "webvm"
    envName = "t"
    target_resource_group_location = "westus"
    target_resource_group_name     = "na-vm-secondary-infra-test-rg"
    staging_resource_group_location = "eastus"
    staging_resource_group_name     = "na-vm-staging-infra-test-rg"
}
```