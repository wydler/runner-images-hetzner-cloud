#!/bin/bash -e
################################################################################
##  File:  Generate-SBOM.sh
##  Desc:  Create SBOM for the release
################################################################################

# Assign script parameters to variables
OutputDirectory="$1"

# Install sysft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generating SBOM
if ! syft dir:/ -o spdx-json="$OutputDirectory/sbom.json"; then
    echo ""
    echo "ERROR: SBOM generation failed."

    if dmesg | grep -qi -E "killed process|out of memory"; then
        echo "Reason: The operating system killed Syft because of insufficient memory (OOM)."
        echo "Syft was likely using too much RAM while scanning '/'."
    else
        echo "Reason: Syft returned an unexpected error."
    fi

    exit 1
fi

# Preparing artifact (raw SBOM.json is too big)
cd $OutputDirectory
zip -r sbom.json.zip sbom.json
