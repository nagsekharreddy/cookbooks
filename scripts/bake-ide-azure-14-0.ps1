﻿<#
.SYNOPSIS

Bake a LANSA image for Azure

.DESCRIPTION

.EXAMPLE


#>

# $DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"

. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

#******************************************************************************
# ****** N.B. When changing to a new version, there is a reference to the 
# ****** version number in install-lansa-ide.ps1
# ****** Look for "LANSA Integrator JSM Administrator Service 1"
# ****** and replace the version number with the latest string that JSM uses
# ****** when installing. And when a major change is made to these scripts
# ****** pass it as a parameter from here through to the script which needs it
# ****** via the registry.
#******************************************************************************
Bake-IdeMsi -VersionText 'IDESQL-F1' `
            -VersionMajor 14 `
            -VersionMinor 1 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\SPIN0332_LanDVDcut_L4W14100_4138_160727_GA" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName "SQL2014-B-Fimage" `
            -GitBranch "support/L4W14000_IDE_Azure" `
            -Cloud "Azure" `
            -InstallBaseSoftware $false `
            -InstallSQLServer $false `
            -InstallIDE $true
