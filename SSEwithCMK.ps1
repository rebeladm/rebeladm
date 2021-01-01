##### Encypt Azure Windows VM with SSE and CMK #####
##### Setup Azure Resource Group #####

New-AzResourceGroup -Name REBELRG1 -Location "East US"

##### Setup Azure Key Vault #####

Register-AzResourceProvider -ProviderNamespace "Microsoft.KeyVault"
$rkv = New-AzKeyVault -VaultName REBELVMKV1 -Location "East US" -ResourceGroupName REBELRG1 -EnablePurgeProtection
Set-AzKeyVaultAccessPolicy -VaultName REBELVMKV1 -ObjectId xxxxxxxxxxxxxxxx -PermissionsToKeys create,import,delete,list -PermissionsToSecrets set,delete -PassThru
$vk1 = Add-AzKeyVaultKey -VaultName REBELVMKV1 -Name "REBELVMKey" -Destination "Software" 

##### Create DisKEncryptionSet Resource #####

$desconf = New-AzDiskEncryptionSetConfig -Location "East US" -SourceVaultId $rkv.ResourceId -KeyUrl $vk1.Key.Kid -IdentityType SystemAssigned
$des1 = New-AzDiskEncryptionSet -Name RDES1 -ResourceGroupName REBELRG1 -InputObject $desconf
Set-AzKeyVaultAccessPolicy -VaultName REBELVMKV1 -ObjectId $des1.Identity.PrincipalId -PermissionsToKeys wrapkey,unwrapkey,get

##### Create Azure VM with SSE and CMK #####

$vmsubnet = New-AzVirtualNetworkSubnetConfig -Name vmsubnet -AddressPrefix "10.0.2.0/24"
New-AzVirtualNetwork -Name REBELVN1 -ResourceGroupName REBELRG1 -Location "East US" -AddressPrefix "10.0.0.0/16" -Subnet $vmsubnet
New-AzPublicIpAddress -ResourceGroupName REBELRG1 -Location eastus -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "rebelpublic1" -Sku Standard
$rdprule = New-AzNetworkSecurityRuleConfig -Name rebelrdprule -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$rebelnsg = New-AzNetworkSecurityGroup -ResourceGroupName REBELRG1 -Location eastus -Name rebelNSG1 -SecurityRules $rdprule
$rebelvnet = Get-AzVirtualNetwork -Name REBELVN1 -ResourceGroupName REBELRG1
$publicip = Get-AzPublicIpAddress -Name rebelpublic1 -ResourceGroupName REBELRG1
$rebelnic1 = New-AzNetworkInterface -Name rebelvmnic1 -ResourceGroupName REBELRG1 -Location eastus -SubnetId $rebelvnet.Subnets[0].Id -PublicIpAddressId $publicip.Id -NetworkSecurityGroupId $rebelnsg.Id
$cred = Get-Credential
$rebelvmconf = New-AzVMConfig -VMName REBEL01 -VMSize Standard_DS1_v2 | Set-AzVMOperatingSystem -Windows -ComputerName REBEL01 -Credential $cred | Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-Datacenter -Version latest | Add-AzVMNetworkInterface -Id $rebelnic1.Id
$des = Get-AzDiskEncryptionSet -ResourceGroupName REBELRG1 -Name RDES1
$VM = "REBEL01"
$rebelvmconf = Set-AzVMOSDisk -VM $rebelvmconf -Name $($VM +"_OSDisk") -DiskEncryptionSetId $des.Id -CreateOption FromImage
$rebelvmconf = Add-AzVMDataDisk -VM $rebelvmconf -Name $($VM +"DataDisk1") -DiskSizeInGB 128 -StorageAccountType Premium_LRS -CreateOption Empty -Lun 0 -DiskEncryptionSetId $des.Id 
New-AzVM -ResourceGroupName REBELRG1 -Location "East US" -VM $rebelvmconf -Verbose
