locals {
  # https://docs.microsoft.com/en-us/azure/devtest-labs/add-artifact-repository
  password                     = ".Az9${random_string.password.result}"
  suffix                       = random_string.suffix.result
  tags                         = map(
    "application",               "Dev/Test Lab",
    "environment",               "dev",
    "provisioner",               "terraform",
    "suffix",                    local.suffix,
    "workspace",                 terraform.workspace
  )
}

data http localpublicip {
# Get public IP address of the machine running this terraform template
  url                          = "http://ipinfo.io/ip"
}

data http localpublicprefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.localpublicip.body)}"
}

data azurerm_client_config current {}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "!@#%*)(-_=+][]}{:?"
}

resource azurerm_resource_group lab_resource_group {
  name                         = "lab-${terraform.workspace}-${local.suffix}"
  location                     = var.location
  tags                         = local.tags
}

resource azurerm_role_assignment vm_admin {
  scope                        = azurerm_resource_group.lab_resource_group.id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.admin_object_id

  count                        = var.admin_object_id != null ? 1 : 0
}

# resource azurerm_storage_account automation {
#   name                         = "${lower(replace(azurerm_resource_group.lab_resource_group.name,"-",""))}${local.suffix}aut"
#   location                     = azurerm_resource_group.lab_resource_group.location
#   resource_group_name          = azurerm_resource_group.lab_resource_group.name
#   account_kind                 = "StorageV2"
#   account_tier                 = "Standard"
#   account_replication_type     = "LRS"
#   allow_blob_public_access     = true
#   enable_https_traffic_only    = true

#   tags                         = local.tags
# }

resource azurerm_storage_account diagnostics {
  name                         = "${lower(replace(azurerm_resource_group.lab_resource_group.name,"-",""))}${local.suffix}diag"
  location                     = azurerm_resource_group.lab_resource_group.location
  resource_group_name          = azurerm_resource_group.lab_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = local.tags
}

resource azurerm_dev_test_lab lab {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-lab"
  location                     = azurerm_resource_group.lab_resource_group.location
  resource_group_name          = azurerm_resource_group.lab_resource_group.name

  tags                         = local.tags
}

resource azurerm_template_deployment artifacts_repository {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-artifacts"
  resource_group_name          = azurerm_resource_group.lab_resource_group.name
  deployment_mode              = "Incremental"

  template_body                = file("${path.module}/lab-artifact-repository.json")

  parameters                   = {
    labName                    = azurerm_dev_test_lab.lab.name
    artifactRepoBranch         = var.artifact_repository_branch
    artifactRepoSecurityToken  = var.artifact_repository_token
    artifactRepoUri            = var.artifact_repository_url
    artifactRepositoryDisplayName = var.artifact_repository_display_name
  }

  depends_on                   = [azurerm_dev_test_lab.lab] # Explicit dependency for ARM templates
}

resource azurerm_dev_test_virtual_network network {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-network"
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_resource_group.lab_resource_group.name

  subnet {
    use_public_ip_address      = "Allow"
    use_in_virtual_machine_creation = "Allow"
  }

  tags                         = local.tags
}

data azurerm_key_vault lab_vault {
  name                         = element(split("/",azurerm_dev_test_lab.lab.key_vault_id),length(split("/",azurerm_dev_test_lab.lab.key_vault_id))-1)
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
}

resource azurerm_dev_test_windows_virtual_machine example {
  name                         = substr(lower(replace("${azurerm_resource_group.lab_resource_group.name}-vm0","-","")),0,15) 
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_resource_group.lab_resource_group.name
  location                     = azurerm_resource_group.lab_resource_group.location
  size                         = var.pool_vm_size
  username                     = var.admin_user_name
  password                     = random_string.password.result
  lab_virtual_network_id       = azurerm_dev_test_virtual_network.network.id
  lab_subnet_name              = azurerm_dev_test_virtual_network.network.subnet[0].name
  storage_type                 = "Premium"
  notes                        = "Initially created VM adeed to claimable pool"

  gallery_image_reference {
    offer                      = "WindowsServer"
    publisher                  = "MicrosoftWindowsServer"
    sku                        = "2019-Datacenter"
    version                    = "latest"
  }

  tags                         = local.tags
}