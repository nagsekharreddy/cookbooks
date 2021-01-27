﻿<#
.SYNOPSIS

Initialise the baking environment

.DESCRIPTION



.EXAMPLE


#>

# Note that this script is called from other functions than bake-ide-ami.ps1, so don't presume values exist - test them first.
# And strict mode is on, so you need to use test-path to test for its existence.
# Like this...
if (test-path variable:\script:VersionText) {
    $script:SG = $script:VersionText
}

$script:externalip = $null

if ( test-path variable:\script:KeyPairName) {
    $script:keypair = $script:KeyPairName
}

if ( test-path variable:\script:KeyPairPath) {
    $script:keypairfile = $script:KeyPairPath
}

$script:licensekeypassword = "nothing"
if ( test-path variable:\script:IncludeDir) {
    $script:ChefRecipeLocation = "$script:IncludeDir\..\ChefCookbooks"
}
$Script:GitRepo = 'lansa'
$Script:GitRepoPath = "c:\$Script:GitRepo"
$Script:ScriptTempPath = "c:\temp"
$Script:LicenseKeyPath = $Script:ScriptTempPath
$Script:InstanceProfileArn = "arn:aws:iam::775488040364:instance-profile/LansaInstalls_ec2"
$Script:DVDDir = 'c:\LanDvdCut'

# Make non-terminating errors into terminating errors. That is, the script will throw an exception so we know its gone wrong
$ErrorActionPreference = 'Stop'

# Make ALL encodings default to utf8. This is to fix command line utilities like pskill producing utf-16
# output which CloudFormation cannot handle.
# This syntax is PowerShell >= 3.0 compatible
# A better solution is just to effect >, >> and out-file but it requires PS 5.1
# Once win2012 support is no longer required, this should be changed
# $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
# *** Following did NOT work on PS 4.0!
# $PSDefaultParameterValues['*:Encoding'] = 'utf8'

cmd /c exit 0       # Set $LASTEXITCODE so it always exists. Saves testing it everywhere

Write-Debug "Variables loaded"
