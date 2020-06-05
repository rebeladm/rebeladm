########### Create New RG ###############

New-AzResourceGroup -Name REBELRG1 -Location “East US”

########### Create New Virtual Network ##################

$vmsubnet = New-AzVirtualNetworkSubnetConfig -Name vmsubnet -AddressPrefix “10.0.2.0/24”

New-AzVirtualNetwork -Name REBELVN1 -ResourceGroupName REBELRG1 -Location “East US” -AddressPrefix “10.0.0.0/16” -Subnet $vmsubnet

########### Create New VM for Testing ####################

$mylogin = Get-Credential

New-AzVm -ResourceGroupName REBELRG1 -Name “REBELTVM01” -Location “East US” -VirtualNetworkName “REBELVN1” -SubnetName “vmsubnet” -addressprefix 10.0.2.0/24 -PublicIpAddressName “REBELVM01IP1” -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

########### Create Snapshot ###############

$vm = Get-Azvm -ResourceGroupName REBELRG1 -Name REBELTVM01

$snapshotconf =  New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location “East US” -CreateOption copy

New-AzSnapshot -Snapshot $snapshotconf -SnapshotName rebelvmsnap1 -ResourceGroupName REBELRG1

############ Set variable with snapshot data #############

$snapshot = Get-AzSnapshot -ResourceGroupName REBELRG1 -SnapshotName rebelvmsnap1

########### Create New Managed Disk for second VM using snapshot ###############

$diskconfig = New-AzDiskConfig -Location “East US” -SourceResourceId $snapshot.Id -CreateOption Copy

$newdisk = New-AzDisk -Disk $diskconfig -ResourceGroupName REBELRG1 -DiskName REBELSNAPDISK1

########### Create new VM configuration #############

$rebelvmconfig = New-AzVMConfig -VMName REBELTVM02 -VMSize Standard_D2s_v3

########### Attach new managed disk as OS disk to new VM configuration ###########

$rebelvmconfig = Set-AzVMOSDisk -VM $rebelvmconfig -ManagedDiskId $newdisk.Id -CreateOption Attach -Windows

########### Create new public IP #################

$vmpublicip = New-AzPublicIpAddress -Name REBELVM02IP1 -ResourceGroupName REBELRG1 -Location “East US” -AllocationMethod Dynamic

########### Create new NIC for VM ################

$vnet = Get-AzVirtualNetwork -Name REBELVN1 -ResourceGroupName REBELRG1   
$subnet = Get-AzVirtualNetworkSubnetConfig -Name vmsubnet -VirtualNetwork $vnet

$vmnic = New-AzNetworkInterface -Name "REBELTVM02_nic1" -ResourceGroupName REBELRG1 -Location “East US” -SubnetId $subnet.Id -PublicIpAddressId $vmpublicip.Id

$rebelvmconfig = Add-AzVMNetworkInterface -VM $rebelvmconfig -Id $vmnic.Id

########### Create second VM ####################

New-AzVM -VM $rebelvmconfig -ResourceGroupName REBELRG1 -Location “East US”
