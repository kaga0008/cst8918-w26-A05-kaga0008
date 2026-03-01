# Configure the Terraform runtime requirements.
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    # Azure Resource Manager provider and version
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

# Define providers and their config params
provider "azurerm" {
  # Leave the features block empty to accept all defaults
  features {}
}

provider "cloudinit" {
  # Configuration options
}

# Variables 
variable "labelPrefix" {
  type    = string
  default = "kaga0008"
}

variable "region" {
  type    = string
  default = "canadacentral"
}

variable "admin_username" {
  type    = string
  default = "az_vm_admin"
}

# Resource group
resource "azurem_resource_group" "azure_rg" {
  name              = "${var.labelPrefix}-A05-RG"
  location          = "var.region"
}

# Virtual Network
resource "azurerm_virtual_network" "azure_vnet" {
  name                = "${var.labelPrefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = azurerm_resource_group.azure_rg.location 
}

# Subnet
resource "azurerm_subnet" "azure_subnet" {
  name                  = "${var.labelPrefix}-subnet"
  resource_group_name   = azurerm_resource_group.azure_rg.name
  virtual_network_name  = azurerm_virtual_network.azure_rg.name
  address_prefixes      = ["10.0.1.0/24"]
}

# Security Group
resource "azurerm_network_security_group" "azure_nsg" {
  name                = "${var.labelPrefix}-security-group"
  location            = azurerm_resource_group.azure_rg.location
  resource_group_name = azurerm_resource_group.azure_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# IP
resource "azurerm_public_ip" "azure_public_ip" {
  name                = "${var.labelPrefix}-public-ip"
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = azurerm_resource_group.azure_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC 
resource "azurerm_network_interface" "azure_nic" {
  name                = "${var.labelPrefix}-nic"
  location            = azurerm_resource_group.azure_rg.location
  resource_group_name = azurerm_resource_group.azure_rg.name

  ip_configuration {
    name                          = "${var.labelPrefix}-internal-ip"
    subnet_id                     = azurerm_subnet.azure_subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.azure_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "azure_nic_association" {
  network_interface_id      = azurerm_network_interface.azure_nic.id
  network_security_group_id = azurerm_network_security_group.azure_nsg.id
}

resource "azurerm_linux_virtual_machine" "azure_vm" {
  name                = "${var.labelPrefix}-virtual-machine"
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = azurerm_resource_group.azure_rg.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "${var.labelPrefix}-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}