locals {
  lab_custom_network_id        = azurerm_template_deployment.custom_network_association.outputs["labVirtualNetworkId"]
  # lab_custom_network_id        = jsondecode(azurerm_resource_group_template_deployment.custom_network_association.output_content).labVirtualNetworkId.value
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
}

resource azurerm_dev_test_virtual_network default_network {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-lab-network"
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_resource_group.lab_resource_group.name

  subnet {
    use_public_ip_address      = "Allow"
    use_in_virtual_machine_creation = "Allow"
  }

  tags                         = local.tags
}

resource azurerm_virtual_network custom_network {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-network"
  location                     = azurerm_resource_group.lab_resource_group.location
  resource_group_name          = azurerm_resource_group.lab_resource_group.name
  address_space                = ["10.1.0.0/16"]

  tags                         = local.tags
}

resource azurerm_subnet custom_subnet {
  name                         = "CustomSubnet"
  virtual_network_name         = azurerm_virtual_network.custom_network.name
  resource_group_name          = azurerm_virtual_network.custom_network.resource_group_name
  address_prefixes             = ["10.1.1.0/24"]
}

resource azurerm_template_deployment custom_network_association {
  name                         = "${azurerm_resource_group.lab_resource_group.name}-network-association"
  resource_group_name          = azurerm_resource_group.lab_resource_group.name
  deployment_mode              = "Incremental"

  template_body                = file("${path.module}/lab-network-association.json")
  parameters                   = {
    labId                      = azurerm_dev_test_lab.lab.id
    virtualNetworkId           = azurerm_virtual_network.custom_network.id
    virtualNetworkSubnetId     = azurerm_subnet.custom_subnet.id
  }

  provisioner "local-exec" {
    when                       = destroy
    command                    = "az resource delete --ids ${self.outputs["labVirtualNetworkId"]}"
  }

  # Create this after other Lab resources
  depends_on                   = [
    azurerm_dev_test_virtual_network.default_network
  ]
}

# BUG: https://github.com/terraform-providers/terraform-provider-azurerm/issues/8840
# resource azurerm_resource_group_template_deployment custom_network_association {
#   name                         = "${azurerm_resource_group.lab_resource_group.name}-network-association"
#   resource_group_name          = azurerm_resource_group.lab_resource_group.name
#   deployment_mode              = "Incremental"

#   template_content             = file("${path.module}/lab-network-association.json")
#   parameters_content           = templatefile("${path.module}/lab-network-association-parameters.json",
#     {
#       lab_id                   = azurerm_dev_test_lab.lab.id
#       virtual_network_id       = azurerm_virtual_network.custom_network.id
#       virtual_network_subnet_id= azurerm_subnet.custom_subnet.id
#     }
#   )

#   debug_level                  = "requestContent"

#   # Create this after other Lab resources
#   depends_on                   = [
#     # azurerm_dev_test_virtual_network.default_network
#   ]
# }

resource azurerm_dev_test_policy lab_vm_count_policy {
  name                         = "LabVmCount"
  policy_set_name              = "default"
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
  fact_data                    = ""
  threshold                    = "10"
  evaluator_type               = "MaxValuePolicy"

  tags                         = local.tags
}

resource azurerm_dev_test_policy user_vm_count_policy {
  name                         = "UserOwnedLabVmCount"
  policy_set_name              = "default"
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
  fact_data                    = ""
  threshold                    = "2"
  evaluator_type               = "MaxValuePolicy"

  tags                         = local.tags
}

resource azurerm_dev_test_windows_virtual_machine windows_pool {
  name                         = "${substr(lower(replace("${azurerm_resource_group.lab_resource_group.name}win","-","")),0,14)}${count.index+1}" 
  lab_name                     = azurerm_dev_test_lab.lab.name
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
  location                     = azurerm_resource_group.lab_resource_group.location
  size                         = var.pool_vm_size
  username                     = var.admin_user_name
  password                     = random_string.password.result
  # lab_virtual_network_id       = azurerm_dev_test_virtual_network.default_network.id
  # lab_subnet_name              = azurerm_dev_test_virtual_network.default_network.subnet[0].name
  lab_virtual_network_id       = local.lab_custom_network_id
  lab_subnet_name              = azurerm_subnet.custom_subnet.name
  storage_type                 = "Premium"
  notes                        = "Initially created VM added to claimable pool"

  gallery_image_reference {
    offer                      = "WindowsServer"
    publisher                  = "MicrosoftWindowsServer"
    sku                        = "2019-Datacenter"
    version                    = "latest"
  }

  count                        = var.pool_vm_count

  tags                         = local.tags
}
data azurerm_resources windows_pool {
  name                         = azurerm_dev_test_windows_virtual_machine.windows_pool[count.index].name
  type                         = "Microsoft.Compute/virtualMachines"
  required_tags                = azurerm_dev_test_windows_virtual_machine.windows_pool[count.index].tags
  count                        = var.pool_vm_count
}
resource azurerm_role_assignment vm_admin {
  scope                        = data.azurerm_resources.windows_pool[count.index].resources[0].id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.admin_object_id

  count                        = var.pool_vm_count
}

resource azurerm_dev_test_schedule auto_shutdown {
  name                         = "LabVmsShutdown"
  location                     = azurerm_dev_test_lab.lab.location
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
  lab_name                     = azurerm_dev_test_lab.lab.name
  status                       = "Enabled"

  daily_recurrence {
    time                       = "2300"
  }

  time_zone_id                 = var.timezone
  task_type                    = "LabVmsShutdownTask"

  notification_settings {
    status                     = "Disabled"
  }

  tags                         = local.tags
}

data azurerm_key_vault lab_vault {
  name                         = element(split("/",azurerm_dev_test_lab.lab.key_vault_id),length(split("/",azurerm_dev_test_lab.lab.key_vault_id))-1)
  resource_group_name          = azurerm_dev_test_lab.lab.resource_group_name
}