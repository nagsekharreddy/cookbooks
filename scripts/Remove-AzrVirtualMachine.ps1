function Remove-AzrVirtualMachine {
	<#
	.SYNOPSIS
		This function is used to remove any Azure VMs as well as any attached disks. By default, this function creates a job
		due to the time it takes to remove an Azure VM.

	.EXAMPLE
		PS> Get-AzVm -Name 'BAPP07GEN22' | Remove-AzrVirtualMachine

		This example removes the Azure VM BAPP07GEN22 as well as any disks attached to it.

	.PARAMETER VMName
		The name of an Azure VM. This has an alias of Name which can be used as pipeline input from the Get-AzureRmVM cmdlet.

	.PARAMETER ResourceGroupName
		The name of the resource group the Azure VM is a part of.

	.PARAMETER Wait
		If you'd rather wait for the Azure VM to be removed before returning control to the console, use this switch parameter.
		If not, it will create a job and return a PSJob back.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[string]$VMName,

		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,

		[Parameter()]
		[pscredential]$Credential,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Wait

	)
	process {
		$scriptBlock = {
			param ($VMName,
				$ResourceGroupName)
			$commonParams = @{
				'Name'              = $VMName;
				'ResourceGroupName' = $ResourceGroupName
			}
			$vm = Get-AzVm @commonParams -ErrorAction SilentlyContinue

            if ( $null -eq $vm ){
                return $null
            }

			#region Remove the boot diagnostics disk
			if ($vm.DiagnosticsProfile.bootDiagnostics) {
				Write-Host -Message 'Removing boot diagnostics storage container...'
                $diagSa = [regex]::match($vm.DiagnosticsProfile.bootDiagnostics.storageUri, '^http[s]?://(.+?)\.').groups[1].value

                $VMNameMangled = $vm.Name
                $VMNameMangled = $VMNameMangled -Replace '[-]'          # Strip -
                if ($VMNameMangled.Length -gt 9) {
					$i = 9
				} else {
					$i = $VMNameMangled.Length
				}
                $VMNameMangled = $VMNameMangled.ToLower().Substring(0, $i)    # lower case, and truncate to 8 chars if necessary

				#region Get the VM ID
				$azResourceParams = @{
					'ResourceName'      = $VMName
					'ResourceType'      = 'Microsoft.Compute/virtualMachines'
					'ResourceGroupName' = $ResourceGroupName
				}
				$vmResource = Get-AzResource @azResourceParams
				$vmId = $vmResource.Properties.VmId
				#endregion

				$diagContainerName = ('bootdiagnostics-{0}-{1}' -f $VMNameMangled, $vmId)
				$diagSaRg = (Get-AzStorageAccount | where { $_.StorageAccountName -eq $diagSa }).ResourceGroupName
				$saParams = @{
					'ResourceGroupName' = $diagSaRg
					'Name'              = $diagSa
				}

				Get-AzStorageAccount @saParams | Get-AzStorageContainer | where { $_.Name -eq $diagContainerName } | Remove-AzStorageContainer -Force
			}
			#endregion

			Write-Host -Message 'Removing the Azure VM...'
			$null = $vm | Remove-AzVM -Force
			Write-Host -Message 'Removing the Azure network interface...'
			foreach($nicUri in $vm.NetworkProfile.NetworkInterfaces.Id) {
				$nic = Get-AzNetworkInterface -ResourceGroupName $vm.ResourceGroupName -Name $nicUri.Split('/')[-1]
				Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $vm.ResourceGroupName -Force
				foreach($ipConfig in $nic.IpConfigurations) {
					if($ipConfig.PublicIpAddress -ne $null) {
						Write-Host -Message 'Removing the Public IP Address...'
						Remove-AzPublicIpAddress -ResourceGroupName $vm.ResourceGroupName -Name $ipConfig.PublicIpAddress.Id.Split('/')[-1] -Force
					}
				}
			}


			## Remove the OS disk
			Write-Host -Message 'Removing OS disk...'
			#if ([bool]($($vm.StorageProfile.OSDisk.Vhd).PSobject.Properties.name -match "uri") ) {
            if ($vm.StorageProfile.OSDisk.Vhd -and (Get-Member -inputobject $vm.StorageProfile.OSDisk.Vhd -name "uri" -Membertype Properties)) {
				## Not managed
				$osDiskId = $vm.StorageProfile.OSDisk.Vhd.Uri
				$osDiskContainerName = $osDiskId.Split('/')[-2]

				## TODO: Does not account for resouce group
				$osDiskStorageAcct = Get-AzStorageAccount | where { $_.StorageAccountName -eq $osDiskId.Split('/')[2].Split('.')[0] }
				$osDiskStorageAcct | Remove-AzStorageBlob -Container $osDiskContainerName -Blob $osDiskId.Split('/')[-1]

				#region Remove the status blob
				Write-Host -Message 'Removing the OS disk status blob...'
				$osDiskStorageAcct | Get-AzStorageBlob -Container $osDiskContainerName -Blob "$($vm.Name)*.status" | Remove-AzStorageBlob
				#endregion
			} else {
                ## managed
                Write-Host( "Removing disk $($vm.StorageProfile.OSDisk.Name)" )
                $Disk = Get-AzDisk -ResourceGroupName $ResourceGroupName | where { $_.Name -eq $vm.StorageProfile.OSDisk.Name }
                if ($Disk) {
					$Disk | Out-Default | Write-Host
					$ResourceGroupName | Out-Default | Write-Host
                    Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $Disk -Force
                }
			}

			## Remove any other attached disks
			if ('DataDiskNames' -in $vm.PSObject.Properties.Name -and @($vm.DataDiskNames).Count -gt 0) {
				Write-Host -Message 'Removing data disks...'
				foreach ($uri in $vm.StorageProfile.DataDisks.Vhd.Uri) {
					$dataDiskStorageAcct = Get-AzStorageAccount -Name $uri.Split('/')[2].Split('.')[0]
					$dataDiskStorageAcct | Remove-AzStorageBlob -Container $uri.Split('/')[-2] -Blob $uri.Split('/')[-1]
				}
			}
		}

		if ($Wait.IsPresent) {
			& $scriptBlock -VMName $VMName -ResourceGroupName $ResourceGroupName
		} else {
			$initScript = {
				$null = Login-AzAccount -Credential $Credential
			}
			$jobParams = @{
				'ScriptBlock'          = $scriptBlock
				'InitializationScript' = $initScript
				'ArgumentList'         = @($VMName, $ResourceGroupName)
				'Name'                 = "Azure VM $VMName Removal"
			}
			Start-Job @jobParams
		}
	}
}