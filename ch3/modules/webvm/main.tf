data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

# Create virtual network
resource "azurerm_virtual_network" "vm_app_infra_vnet" {
  name                = "${var.resource_group_location}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_infra_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "ag_gateway_subnet" {
  name                 = "ag-gateway-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_infra_vnet.name
  address_prefixes     = ["10.1.2.0/24"]
}

# Create public for application gateway
resource "azurerm_public_ip" "ag_public_ip" {
  name                = "${var.vmprefix}-ag-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
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
  name                = "${var.vmprefix}-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.vmprefix}-vm-nic-configuration"
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
  name                     = "webdiag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "web_vm" {
  name                  = "${var.vmprefix}-vm"
  admin_username        = "azureuser"
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.web_vm_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "webOsDisk"
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
    storage_account_uri = azurerm_storage_account.web_storage_account.primary_blob_endpoint
  }
}

# Install IIS web server to the virtual machine
resource "azurerm_virtual_machine_extension" "web_server_install" {
  name                       = "${var.vmprefix}-wsi"
  virtual_machine_id         = azurerm_windows_virtual_machine.web_vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/PacktPublishing/Practical-Azure-Infrastructure-Management/main/ch3/install-web-server.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File install-web-server.ps1 -vmName ${azurerm_windows_virtual_machine.web_vm.name}"
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
  name = "${random_pet.prefix.id}-kv"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name = "standard"
  tenant_id = data.azurerm_client_config.current.tenant_id
  access_policy{
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = data.azurerm_client_config.current.object_id
      secret_permissions = ["Set", "Get","Delete","Purge","Recover", "List"]
      key_permissions = ["Create", "Get"]
    }
}

resource "azurerm_key_vault_secret" "web_vm_password" {
  name = "webvm-password"
  value = random_password.password.result
  key_vault_id = azurerm_key_vault.vm_app_vault.id
}

resource "azurerm_application_gateway" "app_app_gw" {
  name = "${var.resource_group_location}-app-gw"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name = "app-gw-ip-config"
    subnet_id = azurerm_subnet.ag_gateway_subnet.id
  }
  frontend_port {
    name = "app-gw-port"
    port = 80
  }
  frontend_ip_configuration {
    name = "app-gw-ip-config"
    public_ip_address_id = azurerm_public_ip.ag_public_ip.id
  }
  backend_address_pool {
    name = "app-gw-backend-pool"
  }
  backend_http_settings {
    name = "app-gw-http-settings"
    cookie_based_affinity = "Disabled"
    port = 80
    protocol = "Http"
    request_timeout = 60
  }
  http_listener {
    name = "app-gw-http-listener"
    frontend_ip_configuration_name = "app-gw-ip-config"
    frontend_port_name = "app-gw-port"
    protocol = "Http"
  }
  request_routing_rule {
    name = "app-gw-rule"
    rule_type = "Basic"
    http_listener_name = "app-gw-http-listener"
    backend_address_pool_name = "app-gw-backend-pool"
    backend_http_settings_name = "app-gw-http-settings"
    priority = 1
  }
}
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "app_gw_nic_assoc" {
  network_interface_id = azurerm_network_interface.web_vm_nic.id
  ip_configuration_name = azurerm_network_interface.web_vm_nic.ip_configuration.0.name
  backend_address_pool_id = one(azurerm_application_gateway.app_app_gw.backend_address_pool).id
}

resource "azurerm_subnet" "bastion_subnet" {
  name = "AzureBastionSubnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vm_app_infra_vnet.name
  address_prefixes = ["10.1.3.0/27"]
  
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name = "${var.resource_group_location}-bastion-ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_bastion_host" "vm_app_bastion" {
  name = "${var.resource_group_location}-bastion"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  scale_units = 2
  copy_paste_enabled = true
  file_copy_enabled = true
  shareable_link_enabled = true
  tunneling_enabled = true
  ip_configuration {
    name = "bastion-ip-config"
    subnet_id = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

