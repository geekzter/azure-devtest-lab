variable admin_object_id {
  default                      = null
}
variable admin_user_name {
  default                      = "labadmin"
}
variable artifact_repository_branch {
  default                      = "main"
}
variable artifact_repository_display_name {
  default                      = "Sample Repository"
}
variable artifact_repository_token {
  default                      = "dummy"
}
variable artifact_repository_url {
  default                      = "https://github.com/geekzter/azure-devtest-lab.git"
}
variable pool_vm_size {
  default                      = "Standard_DS4"
}


# https://azure.microsoft.com/en-us/global-infrastructure/regions/
# https://azure.microsoft.com/en-us/global-infrastructure/services/?products=devtest-lab
# e.g. eastus, northeurope, southeastasia, southindia, uksouth, westeurope, westus2
variable location {
  description                  = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
  default                      = "westeurope"
}
