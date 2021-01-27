﻿<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "Continue"
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

Bake-IdeMsi -VersionText '14.1 EPC141017' `
            -VersionMajor 14 `
            -VersionMinor 1 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\SPIN0334_LanDVDcut_L4W14100_4138_160727_EPC14101x" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v14/VisualLANSA_L4W14100_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v14/Integrator_L4W1400_latest" `
            -AmazonAMIName "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_SP1_Express*" `
            -GitBranch "support/L4W14100_IDE"`
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $true `
            -InstallScalable $false `
            -Win2012 $true
