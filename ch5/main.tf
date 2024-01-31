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