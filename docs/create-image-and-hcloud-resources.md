# GitHub Actions Runner Images

The runner-images project uses [Packer](https://www.packer.io/) to generate disk images for Ubuntu 22.04/24.04. Each image is configured by a HCL2 Packer template that specifies where to build the image (Hetzner Cloud, in this case), and what steps to run to install software and prepare the disk The Packer process initializes a connection to the Hetzner Cloud using hcloud CLI and creates temporary resources required for the build process: a project and a virtual machine from the "clean" image specified in the template.

If the VM deployment succeeds, Packer connects to it using SSH and begins executing installation steps from the template one-by-one.  
If any step fails, image generation is aborted, and the temporary VM is terminated. Packer also attempts to clean up all the temporary resources it created (unless otherwise configured).  
After successful completion of all installation steps, Packer creates a managed image from the temporary VM's disk and deletes the VM.  


- [Build Agent Preparation](#build-agent-preparation)
- [Manual image generation](#manual-image-generation)
- [Manual Image Generation Customization](#manual-image-generation-customization)
  - [Network Security](#network-security)
  - [Azure Subscription Authentication](#azure-subscription-authentication)
- [Generated Machine Deployment](#generated-machine-deployment)
- [Automated image generation](#automated-image-generation)
  - [Required variables](#required-variables)
  - [Optional variables](#optional-variables)
- [Builder variables](#builder-variables)
- [Toolset](#toolset)
- [Post-generation scripts](#post-generation-scripts)
  - [Running scripts](#running-scripts)
  - [Script Details: Ubuntu](#script-details-ubuntu)

## Build Agent Preparation

The build agent is a machine where the Packer process will be started.
You can use any physical or virtual machine running Windows or Linux OS.
Of course, you may also use an [Azure VM](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-cli).
In any case, you will need these software installed:

- Packer 1.8.2 or higher.

  Download and install it manually from [here](https://www.packer.io/downloads) or use [Chocolatey](https://chocolatey.org/):

  ```powershell
  choco install packer
  ```

- Git.

  For Linux - install the latest version from your distro's package repo.

  For Windows - download and install it from [here](https://gitforwindows.org/) or use [Chocolatey](https://chocolatey.org/):

  ```powershell
  choco install git -params '"/GitAndUnixToolsOnPath"'
  ```

- Powershell 5.0 or higher.

  In Windows you already have it.

  For Linux follow instructions [here](https://learn.microsoft.com/en-us/windows-server/administration/linux-package-repository-for-microsoft-software)
  to add Microsoft's Linux Software Repository and then install the `powershell` package.

- Azure CLI.

  Follow the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
  Or if you use Windows, you may run this command in Powershell instead:

  ```powershell
  Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
  Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
  ```

## Manual image generation

This repository includes a script that assists in generating images in Azure.
All you need is an Azure subscription, a resource group in that subscription and a build agent configured as described above.
We suggest starting with building the UbuntuMinimal image because it includes only basic software and builds in less than 30 minutes.

All the commands below should be executed in PowerShell.

First, clone the runner-images repository and set the current directory to it:

```powershell
git clone https://github.com/actions/runner-images.git
Set-Location runner-images
```

Then, import the [GenerateResourcesAndImage](../helpers/GenerateResourcesAndImage.ps1) script from the `helpers` subdirectory:

```powershell
Import-Module .\helpers\GenerateResourcesAndImage.ps1
```

Finally, run the `GenerateResourcesAndImage` function, setting the mandatory arguments: image type and where to build and store the resulting managed image:

- `SubscriptionId` - your Azure Subscription ID;
- `ResourceGroupName` - the name of the resource group that will store the resulting artifact (e.g., "imagegen-test").
    The resource group must already exist in your Azure subscription;
- `AzureLocation` - the location where resources will be created (e.g., "East US");
- `ImageType` - the type of image to build (we suggest choosing "UbuntuMinimal" here; other valid options are "Windows2019", "Windows2022", "Windows2025", "Ubuntu2204", "Ubuntu2404").

This function automatically creates all required Azure resources and initiates the Packer image generation for the selected image type.

When the image is ready, you may proceed to [deployment](#generated-machine-deployment).

## Manual Image Generation Customization

The `GenerateResourcesAndImage` function accepts a number of arguments that may assist you in generating an image in your specific environment.

For example, you may want all the resources involved in the image generation process to be tagged.
In this case, pass a HashTable of tags as a value for the `Tags` parameter.

If you don't want the function to authenticate interactively, you should create a Service Principal and invoke the function with the parameters `AzureClientId`, `AzureClientSecret` and `AzureTenantId`.
You can find more details in the [corresponding section below](#azure-subscription-authentication).

Use `get-help GenerateResourcesAndImage -Detailed` for the complete list of available parameters.

### Network Security

To connect to a temporary virtual machine, Packer uses SSH.

If your build agent is located outside of the Hetzner Cloud where the temporary VM is created, a public network interface and public IP address are used.
Make sure that firewalls are configured properly and that SSH (TCP port 22) connections are allowed both outgoing for the build agent and incoming for the temporary VM.

### Azure Subscription Authentication

Packer uses a Service Principal to authenticate in Azure infrastructure.
For more information about Service Principals, refer to the
[Azure documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal).

The `GenerateResourcesAndImage` function is able to create a Service Principal to be used by Packer.
It uses the Connect-AzAccount cmdlet that invokes an interactive authentication process by default.
If you don't want to use interactive authentication, you should create a Service Principal with full read-write permissions for the selected Azure subscription on your own
and provide proper values for the parameters `AzureClientId`, `AzureClientSecret` and `AzureTenantId`.

Here is an example of how to create a Service Principal using the Az PowerShell module:

```powershell
$credentials = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential]@{
  StartDateTime = Get-Date
  EndDateTime = (Get-Date).AddDays(7)
}

$sp = New-AzADServicePrincipal -DisplayName "imagegen-app"
$appCred = New-AzADAppCredential -ApplicationId $sp.AppId -PasswordCredentials $credentials

Start-Sleep -Seconds 30
New-AzRoleAssignment -RoleDefinitionName "Contributor" -PrincipalId $sp.Id
Start-Sleep -Seconds 30

@{
  ClientId = $sp.AppId
  ClientSecret = $appCred.SecretText
  TenantId = (Get-AzSubscription -SubscriptionId $SubscriptionId).TenantId
}
```

## Generated Machine Deployment

tbd

## Automated image generation

If you want to generate images automatically (e.g., as a part of a CI/CD pipeline), you can use Packer directly. To do this, you will need:

- An active user account in the Hetzner Cloud.
  - A new project (e.g. Github Self-Hosted-Runner) in the Hetzner Cloud console.
  - Create an API token in the project (e.g. Github Self-Hosted Runner) for CI/CD).

- A GitHub application with follow permissions:
  - Read access to metadata
  - Read and write access to code, issues, pull requests, and workflows
  - Generate a private key for use in this repository (see below).
  - Authorize the created GitHub app to this repository.


### Repository Secrets

The follow secrets are required that the CI/CD pipelines process:

| Secret var | Description
| ------------ | -----------
| `GH_APP_RIHC_ID` | The ID of the GitHub app Runner Images Hetzner Cloud.
| `GH_APP_RIHC_PRIVATE_KEY` | The private key for the above-mentioned APP ID. The format must be base64.
| `HCLOUD_TOKEN` | API token for accessing the project in the Hetzner Cloud console. Read and write access required.

### Packer Templates

The following variables are required to be passed to the Packer process:

| Template var | Env var | Description
| ------------ | ------- | -----------
| `server_location` | `HCLOUD_SERVER_LOCATION` | The location of the VM in the Hetzner Cloud.
| `os_image_name` | `HCLOUD_SERVER_IMAGE` | The name of the image to be used (e.g., ubuntu-24.04). If a snapshot is to be used as a template, the snapshot ID must be specified.
| `image_version` | `IMAGE_VERSION` | The unique label for the VM and snapshot as identifier.
| `server_type` | `HCLOUD_SERVER_TYPE` | The type/plan to use for the VM.
| `managed_image_name` | `HCLOUD_OBJECT_NAME` | The display name/description for the VM and snapshot.
| `managed_image_resource_group_name` | `ARM_RESOURCE_GROUP` | The resource group under which the final artifact will be stored.

## Delete old VM templates/snapshots

Over time the project accumulates an increasing number of snapshots for each operating system in the Hetzner Cloud. These incur monthly costs due to the current billing model (per GB).  
Therefore, a GitHub action called "Misc - Delete old VM templates" is available for housekeeping.

The following variables are required:

| Secret var | Description
| ------------ | -----------
| `HCLOUD_TOKEN` | API token for accessing the project in the Hetzner Cloud console. Read and write access required.

| Repo var | Description
| ------------ | -----------
| `KEEP_SNAPSHOTS` | This is a repository variable. The value of the variable indicates how many snapshots (sorted in ascending order) to keep.

There is currently no schedule defined for executing the action. Therefore, by default it has to be started manually.

## Synchronize commits from the original repository 

This repository is a fork of [actions/runner-images](https://github.com/actions/runner-images). All changes from the original repository are synchronized to the branch `main`  every night.  
There is an Github action with the name  "Manage - Sync fork (Branch main)," which is executed every night at 12:00 a.m.

The following variables are required:

| Secret var | Description
| ------------ | -----------
| `GH_APP_SRP_ID` | The ID of the GitHub app Synchronization Repository Fork.
| `GH_APP_SRP_PRIVATE_KEY` | The private key for the above-mentioned APP ID. The format must be base64.

## Builder variables

The `builders` section contains variables for the `source.hcloud.ubuntu-base-image` builder used in the project. Most of the builder variables are inherited from the `user variables` section, however, the variables can be overwritten to adjust image-generation performance.

- `servertype` - the size of the VM used for building; this can be changed when you deploy a VM from your image;
- `location` - specify the location of the VM.

**Detailed Hetzner Cloud builders documentation can be found in the [packer documentation](https://developer.hashicorp.com/packer/integrations/hetznercloud/hcloud).**

## Toolset

The configuration for some installed software is located in `toolset.json` files. These files define the list of Ruby, Python, Go versions, the list of PowerShell modules and VS components that will be installed on the image. They can be changed if these tools are not required, to reduce image generation time or image size.

Generated tool versions and details can be found in related projects:

- [Python](https://github.com/actions/python-versions/)
- [Go](https://github.com/actions/go-versions)
- [Node](https://github.com/actions/node-versions)

## Post-generation scripts

> :warning: These scripts are intended to be run on a VM deployed in Azure

The user, created during the image generation, does not exist in the resulting image. Hence, some configuration files related to the user's home directory need to be changed, as well as the file permissions for some directories. Scripts for that are located in the `post-gen` folder in the repository:

- Linux: <https://github.com/wydler/runner-images-hetzner-cloud/tree/customize/images/ubuntu/assets/post-gen>

**Note:** The default user for Linux should have `sudo privileges`.

The scripts are copied to the image during the generation process to the following paths:

- Linux:  `/opt/post-generation`

### Running scripts

- Ubuntu

  ```bash
  sudo su -c "find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name '*.sh' -exec bash {} \;"
  ```

### Script Details: Ubuntu

- **cleanup-logs.sh** - removes all build process logs from the machine;
- **environment-variables.sh** - replaces `$HOME` with the default user's home directory for environment variables related to the default user home directory;
- **homebrew-permissions.sh** - resets the Homebrew repository directory by running `git reset --hard` to make the working tree clean after changing permissions in /home and changes the repository directory owner to the current user;
- **rust-permissions.sh** - fixes permissions for the Rust folder; a detailed issue explanation is provided in [runner-images/issues/572](https://github.com/actions/runner-images/issues/572).
