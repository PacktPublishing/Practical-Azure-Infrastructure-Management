data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

# Create virtual network
resource "azurerm_virtual_network" "vm_app_infra_vnet" {
  name                = "${var.resource_group_location}-${var.envName}-vnet"
  address_space       = var.resource_group_location == "westeurope" ? ["10.1.0.0/16"] : ["10.2.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "web_subnet" {
  name                 = "${var.envName}-web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_infra_vnet.name
  address_prefixes     = var.resource_group_location == "westeurope" ? ["10.1.1.0/24"] : ["10.2.1.0/24"]
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "web_subnet_nsg" {
  name                = "${azurerm_subnet.web_subnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

# Create network interface
resource "azurerm_network_interface" "web_vm_nic" {
  count = var.vmcount
  name                = "${var.vmprefix}-${var.envName}-vm-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.vmprefix}-${var.envName}-vm-nic-configuration-${count.index}"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the web subnet
resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_subnet_nsg.id
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "web_storage_account" {
  count = var.vmcount
  name                     = "webdiag${random_id.random_id.hex}${count.index}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "web_vm" {
  count = var.vmcount
  name                  = "${var.vmprefix}-${var.envName}-vm-${count.index}"
  computer_name = "${var.vmprefix}-${var.envName}-vm-${count.index}"
  admin_username        = "azureuser"
  admin_password        = random_password.password[count.index].result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.web_vm_nic[count.index].id]
  size                  = "Standard_D2s_v3"
  zone = count.index < 3 ? count.index + 1 : (count.index % 3) + 1

  os_disk {
    name                 = "webOsDisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.web_storage_account[count.index].primary_blob_endpoint
  }
}

# Install IIS web server to the virtual machine
resource "azurerm_virtual_machine_extension" "web_server_install" {
  count = var.vmcount
  name                       = "${var.vmprefix}-${var.envName}-wsi-${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.web_vm[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/PacktPublishing/Practical-Azure-Infrastructure-Management/main/ch3/install-web-server.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File install-web-server.ps1 -vmName ${azurerm_windows_virtual_machine.web_vm[count.index].name}"
    }
  SETTINGS
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

resource "random_password" "password" {
  count = var.vmcount
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

resource "azurerm_key_vault" "vm_app_vault" {
  name                = "${random_pet.prefix.id}-${var.envName}-kv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
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
  count = var.vmcount
  name         = "${var.vmprefix}-${var.envName}-vm-password-${count.index}"
  value        = random_password.password[count.index].result
  key_vault_id = azurerm_key_vault.vm_app_vault.id
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_infra_vnet.name
  address_prefixes     = var.resource_group_location == "westeurope" ? ["10.1.3.0/27"] : ["10.2.3.0/27"]
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "${var.resource_group_location}-bastion-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "vm_app_bastion" {
  name                   = "${var.resource_group_location}-bastion"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  sku                    = "Standard"
  scale_units            = 2
  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = true
  tunneling_enabled      = true
  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

# Create recovery services vault
resource "azurerm_recovery_services_vault" "vm_app_recovery_vault" {
  name                = "${var.resource_group_location}-${var.envName}-recovery-vault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  soft_delete_enabled = false
}

resource "azurerm_backup_policy_vm" "vm_app_backup_policy" {
  name                = "${var.resource_group_location}-${var.envName}-backup-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 30
  }
}

resource "azurerm_backup_protected_vm" "vm_app_protected_vm" {
  count                = var.vmcount
  resource_group_name  = azurerm_resource_group.rg.name
  recovery_vault_name  = azurerm_recovery_services_vault.vm_app_recovery_vault.name
  source_vm_id         = azurerm_windows_virtual_machine.web_vm[count.index].id
  backup_policy_id     = azurerm_backup_policy_vm.vm_app_backup_policy.id
}