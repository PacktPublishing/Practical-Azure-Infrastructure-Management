# Create a resource group
resource "azurerm_resource_group" "nodes_rg" {
    name     = "iac-book-nodes-rg"
    location = "West Europe"
}

# Create a virtual network
resource "azurerm_virtual_network" "node_vnet" {
    name                = "node-virtual-network"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.nodes_rg.location
    resource_group_name = azurerm_resource_group.nodes_rg.name
}

# Create a subnet
resource "azurerm_subnet" "web_subnet" {
    name                 = "web-subnet"
    resource_group_name  = azurerm_resource_group.nodes_rg.name
    virtual_network_name = azurerm_virtual_network.node_vnet.name
    address_prefixes     = ["10.0.1.0/24"]
}
data "http" "winrm_setup_script" {
  url = "https://raw.githubusercontent.com/ansible/ansible-documentation/ae8772176a5c645655c91328e93196bcf741732d/examples/scripts/ConfigureRemotingForAnsible.ps1" 
}

# Create a Windows virtual machine
resource "azurerm_windows_virtual_machine" "windows_vm" {
    name                = "windows-vm-01"
    resource_group_name = azurerm_resource_group.nodes_rg.name
    location            = azurerm_resource_group.nodes_rg.location
    size                = "Standard_DS2_v2"
    admin_username      = "adminuser"
    admin_password      = "Password123!"

    network_interface_ids = [azurerm_network_interface.windows_vm_nic.id]

    os_disk {
        name              = "windows-vm-osdisk"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-Datacenter"
        version   = "latest"
    }
    tags = {
      applicationRole = "winserver"
    }
}

resource "azurerm_virtual_machine_extension" "winrm_setup_script_extension" {

    name                 = "ConfigureRemotingForAnsible"
    virtual_machine_id   = azurerm_windows_virtual_machine.windows_vm.id
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.10"
    
    settings = <<SETTINGS
    {
        "fileUris": ["${data.http.winrm_setup_script.url}"],
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
    }
   SETTINGS
}

resource "azurerm_network_security_group" "node_nsg" {
    name                = "node-nsg"
    location            = azurerm_resource_group.nodes_rg.location
    resource_group_name = azurerm_resource_group.nodes_rg.name

    security_rule {
        name                       = "Allow-SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-HTTPS"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-RDP"
        priority                   = 1004
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-WinRM"
        priority                   = 1005
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5986"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-ICMP"
        priority                   = 1007
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Icmp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "linux_vm" {
    name                = "linux-vm-01"
    resource_group_name = azurerm_resource_group.nodes_rg.name
    location            = azurerm_resource_group.nodes_rg.location
    size                = "Standard_DS2_v2"
    admin_username      = "adminuser"
    admin_password      = "Password123!"
    disable_password_authentication = false

    network_interface_ids = [azurerm_network_interface.linux_vm_nic.id]

    os_disk {
        name              = "linux-vm-osdisk"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    tags = {
      applicationRole = "linuxserver"
    }
}

# Create a network interface for the Windows VM
resource "azurerm_network_interface" "windows_vm_nic" {
    name                = "my-windows-nic"
    resource_group_name = azurerm_resource_group.nodes_rg.name
    location            = azurerm_resource_group.nodes_rg.location

    ip_configuration {
        name                          = "windows-ipconfig"
        subnet_id                     = azurerm_subnet.web_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.windows_vm_pip.id
    }
}

# Create a network interface for the Linux VM
resource "azurerm_network_interface" "linux_vm_nic" {
    name                = "my-linux-nic"
    resource_group_name = azurerm_resource_group.nodes_rg.name
    location            = azurerm_resource_group.nodes_rg.location

    ip_configuration {
        name                          = "linux-ipconfig"
        subnet_id                     = azurerm_subnet.web_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.linux_vm_pip.id
    }
}

# Create a public IP address for the Windows VM
resource "azurerm_public_ip" "windows_vm_pip" {
    name                = "windows-pip"
    location            = azurerm_resource_group.nodes_rg.location
    resource_group_name = azurerm_resource_group.nodes_rg.name
    allocation_method   = "Dynamic"
}

# Create a public IP address for the Linux VM
resource "azurerm_public_ip" "linux_vm_pip" {
    name                = "linux-pip"
    location            = azurerm_resource_group.nodes_rg.location
    resource_group_name = azurerm_resource_group.nodes_rg.name
    allocation_method   = "Dynamic"
}