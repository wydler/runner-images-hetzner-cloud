# GitHub Actions Runner Images

The runner-images project uses [Packer](https://www.packer.io/) to generate disk images for Ubuntu 22.04/24.04. Each image is configured by a HCL2 Packer template that specifies where to build the image (Hetzner Cloud, in this case), and what steps to run to install software and prepare the disk The Packer process initializes a connection to the Hetzner Cloud using hcloud CLI and creates temporary resources required for the build process: a project and a virtual machine from the "clean" image specified in the template.

If the VM deployment succeeds, Packer connects to it using SSH and begins executing installation steps from the template one-by-one.  
If any step fails, image generation is aborted, and the temporary VM is terminated. Packer also attempts to clean up all the temporary resources it created (unless otherwise configured).  
After successful completion of all installation steps, Packer creates a managed image from the temporary VM's disk and deletes the VM.  


- [Generated Machine Deployment](#generated-machine-deployment)
- [Automated image generation](#automated-image-generation)
  - [Required variables](#required-variables)
  - [Optional variables](#optional-variables)
- [Builder variables](#builder-variables)
- [Toolset](#toolset)
- [Post-generation scripts](#post-generation-scripts)
  - [Running scripts](#running-scripts)
  - [Script Details: Ubuntu](#script-details-ubuntu)

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
| `hcloud_token` | `HCLOUD_TOKEN` | API token for accessing the project in the Hetzner Cloud console. Read and write access required.
| `server_location` | `HCLOUD_SERVER_LOCATION` | The location of the VM in the Hetzner Cloud.
| `os_image_name` | `HCLOUD_SERVER_IMAGE` | The name of the image to be used (e.g., ubuntu-24.04). If a snapshot is to be used as a template, the snapshot ID must be specified.
| `image_version` | `IMAGE_VERSION` | A unique name for the image version within the runner.
| `server_type` | `HCLOUD_SERVER_TYPE` | The type/plan to use for the VM.
| `managed_image_name` | `HCLOUD_OBJECT_NAME` | The display name/description for the VM and snapshot in the Hetzner Cloud console.

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
