terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }
  }
}

# Main provider configuration

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "prod1" {
 
  name     = "prod11"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet-1" {
  name                = "Vnet-1"
  location            = azurerm_resource_group.prod1.location
  resource_group_name = azurerm_resource_group.prod1.name
  address_space       = ["10.1.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "prodvent1subnet1" {
  name                 = "prod-vent1-subnet1"
  resource_group_name  = azurerm_resource_group.prod1.name
  virtual_network_name = azurerm_virtual_network.vnet-1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = azurerm_resource_group.prod1.location
  resource_group_name = azurerm_resource_group.prod1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prodvent1subnet1.id
    private_ip_address_allocation = "Dynamic"
    
  }
}

resource "azurerm_network_interface" "nic2" {
  name                = "nic2"
  location            = azurerm_resource_group.prod1.location
  resource_group_name = azurerm_resource_group.prod1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prodvent1subnet1.id
    private_ip_address_allocation = "Dynamic"
    
  }
}

resource "azurerm_virtual_machine" "vm1" {
  name                  = "vm1"
  location              = azurerm_resource_group.prod1.location
  resource_group_name   = azurerm_resource_group.prod1.name
  network_interface_ids = [azurerm_network_interface.nic1.id]
  vm_size               = "Standard_D4s_v5"


  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "vm-1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
lifecycle {
    ignore_changes = all
  }
  }

  resource "azurerm_virtual_machine" "vm2" {
  name                  = "vm2"
  location              = azurerm_resource_group.prod1.location
  resource_group_name   = azurerm_resource_group.prod1.name
  network_interface_ids = [azurerm_network_interface.nic2.id]
  vm_size               = "Standard_D4s_v5"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  
  storage_os_disk {
    name              = "vm-2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
lifecycle {
    ignore_changes = all
  }
  }

resource "azurerm_public_ip" "ip" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.prod1.location
  resource_group_name = azurerm_resource_group.prod1.name
  allocation_method   = "Static"
}
  resource "azurerm_lb" "example" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.prod1.location
  resource_group_name = azurerm_resource_group.prod1.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.ip.id
  }
  sku = "Standard"
}

resource "azurerm_lb_backend_address_pool" "backendpool" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_backend_address_pool_address" "vm1_association" {
  name                    = "address2"
  virtual_network_id = azurerm_virtual_network.vnet-1.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
  ip_address              = azurerm_network_interface.nic1.private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "vm_2association" {
    name                    = "address1"
virtual_network_id = azurerm_virtual_network.vnet-1.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
  ip_address              = azurerm_network_interface.nic2.private_ip_address
}

resource "azurerm_lb_probe" "prob" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "ssh-running-probe"
  port            = 80
}

resource "azurerm_lb_rule" "rule" {
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
}
