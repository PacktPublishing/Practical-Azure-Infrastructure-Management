resource "azurerm_resource_group" "ansible_rg" {
  name     = "iac-book-ansible-rg"
  location = "westeurope"
}

resource "azurerm_network_security_group" "ansible_vm_nsg" {
  name                = "ansible-nsg"
  location            = azurerm_resource_group.ansible_rg.location
  resource_group_name = azurerm_resource_group.ansible_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "ansible_vnet" {
  name                = "ansible-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ansible_rg.location
  resource_group_name = azurerm_resource_group.ansible_rg.name
}

resource "azurerm_subnet" "ansible_subnet" {
  name                 = "ansible-subnet"
  resource_group_name  = azurerm_resource_group.ansible_rg.name
  virtual_network_name = azurerm_virtual_network.ansible_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ansible_public_ip" {
  name                = "ansible-pip"
  location            = azurerm_resource_group.ansible_rg.location
  resource_group_name = azurerm_resource_group.ansible_rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "ansible_nic" {
  name                = "ansible-nic"
  location            = azurerm_resource_group.ansible_rg.location
  resource_group_name = azurerm_resource_group.ansible_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ansible_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ansible_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "ansible_vm" {
  name                = "ansible-vm"
  resource_group_name = azurerm_resource_group.ansible_rg.name
  location            = azurerm_resource_group.ansible_rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password = "MyAnsible@123"
  disable_password_authentication = false
  
  network_interface_ids = [
    azurerm_network_interface.ansible_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  //custom_data = filebase64("${path.module}/ansible-cloud-init.txt")
  custom_data = filebase64("${path.module}/install-ansible.sh")
}
