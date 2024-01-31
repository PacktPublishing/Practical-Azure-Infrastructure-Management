data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "source_rg" {
  location = var.source_resource_group_location
  name     = var.source_resource_group_name
}

# Create source virtual network
resource "azurerm_virtual_network" "vm_app_source_infra_vnet" {
  name                = "${var.source_resource_group_location}-${var.envName}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
}

# Create subnet
resource "azurerm_subnet" "web_source_subnet" {
  name                 = "${var.envName}-web-source-subnet"
  resource_group_name  = azurerm_resource_group.source_rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_source_infra_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "source_web_subnet_nsg" {
  name                = "${azurerm_subnet.web_source_subnet.name}-nsg"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create primary public ip
resource "azurerm_public_ip" "source_vm_app_pip" {
  name                = "${var.vmprefix}-${var.envName}-pip-vm-app"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
  allocation_method   = "Dynamic"
}

# Create network interface
resource "azurerm_network_interface" "source_web_vm_nic" {
  name                = "${var.vmprefix}-${var.envName}-vm-nic"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name

  ip_configuration {
    name                          = "${var.vmprefix}-${var.envName}-vm-nic-configuration"
    subnet_id                     = azurerm_subnet.web_source_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.source_vm_app_pip.id
  }
}

# Connect the security group to the web subnet
resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_source_subnet.id
  network_security_group_id = azurerm_network_security_group.source_web_subnet_nsg.id
}

# Create virtual machine
resource "azurerm_virtual_machine" "source_web_vm" {
  name                  = "${var.vmprefix}-${var.envName}-vm"
  location              = azurerm_resource_group.source_rg.location
  resource_group_name   = azurerm_resource_group.source_rg.name
  network_interface_ids = [azurerm_network_interface.source_web_vm_nic.id]
  vm_size =             "Standard_D2s_v3"
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination = true

  storage_os_disk {
    name                 = "webOsDisk-01"
    caching              = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
 }
 os_profile {
    computer_name  = "${var.vmprefix}-${var.envName}-vm"
    admin_username = "azureuser"
    admin_password = random_password.password.result
  }

  os_profile_windows_config {
    provision_vm_agent = true
 }
storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest" 
  }
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.source_rg.name
  }

  byte_length = 8
}

resource "random_id" "random_stg_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.target_rg.name
  }

  byte_length = 8
}
resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

resource "random_pet" "prefix" {
  prefix = var.vmprefix
  length = 1
}

resource "azurerm_key_vault" "source_vm_app_vault" {
  name                = "${random_pet.prefix.id}-${var.envName}-kv"
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Set", "Get", "Delete", "Purge", "Recover", "List"]
    key_permissions    = ["Create", "Get"]
  }
}

resource "azurerm_key_vault_secret" "web_vm_password" {
  name         = "${var.vmprefix}-${var.envName}-vm-password"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.source_vm_app_vault.id
}


resource "azurerm_resource_group" "target_rg" {
  location = var.target_resource_group_location
  name     = var.target_resource_group_name  
}

# DR resources

# Create recovery vault

resource "azurerm_recovery_services_vault" "vm_app_recovery_vault" {
  name                = "${var.target_resource_group_location}-${var.envName}-recovery-vault"
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name
  sku                 = "Standard"
  soft_delete_enabled = false
}

# Create source and target fabric
resource "azurerm_site_recovery_fabric" "source" {
  name = "source-fabric-1"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  location = azurerm_resource_group.source_rg.location
}

resource "azurerm_site_recovery_fabric" "target" {
  name = "target-fabric-1"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  location = azurerm_resource_group.target_rg.location
}

# Create source and target protection container
resource "azurerm_site_recovery_protection_container" "source" {
  name = "source-protection-container"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  recovery_fabric_name = azurerm_site_recovery_fabric.source.name
}

resource "azurerm_site_recovery_protection_container" "target" {
  name = "target-protection-container"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  recovery_fabric_name = azurerm_site_recovery_fabric.target.name  
}

# Create replication policy
resource "azurerm_site_recovery_replication_policy" "policy" {
  name = "policy"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  recovery_point_retention_in_minutes = 24*60
  application_consistent_snapshot_frequency_in_minutes = 4*60
}

# Create container mapping
resource "azurerm_site_recovery_protection_container_mapping" "container_mapping" {
  name = "container-mapping"
  resource_group_name = azurerm_resource_group.target_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  recovery_fabric_name = azurerm_site_recovery_fabric.source.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.source.name
  recovery_target_protection_container_id = azurerm_site_recovery_protection_container.target.id
  recovery_replication_policy_id = azurerm_site_recovery_replication_policy.policy.id
}

# Create target virtual network and subnet
resource "azurerm_virtual_network" "vm_app_target_infra_vnet" {
  name                = "${var.target_resource_group_location}-${var.envName}-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.target_rg.location
  resource_group_name = azurerm_resource_group.target_rg.name
}

resource "azurerm_subnet" "target_web_subnet" {
  name                 = "${var.envName}-web-target-subnet"
  resource_group_name  = azurerm_resource_group.target_rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_target_infra_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

# Create network mapping
resource "azurerm_site_recovery_network_mapping" "network-mapping" {
  name                        = "network-mapping"
  resource_group_name         = azurerm_resource_group.target_rg.name
  recovery_vault_name         = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.source.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.target.name
  source_network_id           = azurerm_virtual_network.vm_app_source_infra_vnet.id
  target_network_id           = azurerm_virtual_network.vm_app_target_infra_vnet.id
}

# Create target public ip
resource "azurerm_public_ip" "target_pip_vm_app" {
  name                    = "target-pip"
  location                = azurerm_resource_group.target_rg.location
  resource_group_name     = azurerm_resource_group.target_rg.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

# Create staging resource group and storage account
resource "azurerm_resource_group" "staging_rg" {
  location = var.staging_resource_group_location
  name     = var.staging_resource_group_name
  
}

resource "azurerm_storage_account" "primary" {
  name                     = "stg${random_id.random_stg_id.hex}"
  location                 = azurerm_resource_group.staging_rg.location
  resource_group_name      = azurerm_resource_group.staging_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create replication

resource "azurerm_site_recovery_replicated_vm" "vm_app_replication" {
  name                                      = "${var.vmprefix}-${var.envName}-vm-replication"
  resource_group_name                       = azurerm_resource_group.target_rg.name
  recovery_vault_name                       = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.source.name
  source_vm_id                              = azurerm_virtual_machine.source_web_vm.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.policy.id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.source.name

  target_resource_group_id                = azurerm_resource_group.target_rg.id
  target_recovery_fabric_id               = azurerm_site_recovery_fabric.target.id
  target_recovery_protection_container_id = azurerm_site_recovery_protection_container.target.id
  
 managed_disk {
    disk_id                    = azurerm_virtual_machine.source_web_vm.storage_os_disk.0.managed_disk_id
    staging_storage_account_id = azurerm_storage_account.primary.id
    target_resource_group_id   = azurerm_resource_group.target_rg.id
    target_disk_type           = azurerm_virtual_machine.source_web_vm.storage_os_disk.0.managed_disk_type
    target_replica_disk_type   = azurerm_virtual_machine.source_web_vm.storage_os_disk.0.managed_disk_type
  }
  network_interface {
    source_network_interface_id = azurerm_network_interface.source_web_vm_nic.id
    target_subnet_name = azurerm_subnet.target_web_subnet.name
    recovery_public_ip_address_id = azurerm_public_ip.target_pip_vm_app.id
  }
  depends_on = [ azurerm_site_recovery_protection_container_mapping.container_mapping, azurerm_site_recovery_network_mapping.network-mapping]
}