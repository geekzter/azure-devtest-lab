# azure-devtest-lab

This is a demo of how Azure DevTest Lab deployment can be provisioned using Terraform.
[Azure DevTest Labs](http://aka.ms/dtl) is a self-service provisioning VM environment for development teams. Vm's can be used for development are integrated into CI/CD (e.g. in an [Azure Pipeline](https://docs.microsoft.com/en-us/azure/devtest-labs/devtest-lab-integrate-ci-cd)). Provisioning is bound to policies e.g. VM types, # VM's, etc. Users can configure VM's with standard artifacts of custom ones.

The provisoned lab contains:
* Policies for # of VM's per lab and per user
* The default as wel as a custom virtual network connected to the Lab
* A shutdown schedule
* A custom artifact repository

Prep-requisites:
* [Azure CLI](http://aka.ms/azure-cli)
* [Terraform](https://www.terraform.io/downloads.html) (to get that use [tfenv](https://github.com/tfutils/tfenv) on Linux/macOS, [Homebrew](https://github.com/hashicorp/homebrew-tap) on macOS or [chocolatey](https://chocolatey.org/packages/terraform) on Windows)


## Resources
- [Azure DevTest Labs documentation](https://docs.microsoft.com/en-us/azure/devtest-labs/devtest-lab-overview)
- [Terraform Azure Provider](https://www.terraform.io/docs/providers/azurerm/index.html)
- [Terraform on Azure documentation](https://docs.microsoft.com/en-us/azure/developer/terraform)
