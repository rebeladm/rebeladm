
##### Create Resource Groups #####
New-AzResourceGroup -Name EUSRG1 -Location “East US”
New-AzResourceGroup -Name UKSRG1 -Location “UK South”
New-AzResourceGroup -Name BASRG1 -Location “West US”

##### Create Vritual Network in East US Resource Group #####
$vmsubnet = New-AzVirtualNetworkSubnetConfig -Name vmsubnet -AddressPrefix “10.15.0.0/24”
New-AzVirtualNetwork -Name EUSVnet1 -ResourceGroupName EUSRG1 -Location “East US” -AddressPrefix “10.15.0.0/16” -Subnet $vmsubnet

##### Create Virtual Network on UK South Resource Group #####
$vmsubnet2 = New-AzVirtualNetworkSubnetConfig -Name vmsubnet2 -AddressPrefix “10.75.0.0/24”
New-AzVirtualNetwork -Name UKSVnet1 -ResourceGroupName UKSRG1 -Location “UK South” -AddressPrefix “10.75.0.0/16” -Subnet $vmsubnet2

##### Create Test VM #####
$mylogin = Get-Credential
New-AzVm -ResourceGroupName EUSRG1 -Name “EUSRGVM01” -Location “East US” -VirtualNetworkName “EUSVnet1” -SubnetName “vmsubnet” -addressprefix 10.15.0.0/24 -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

$mylogin = Get-Credential
New-AzVm -ResourceGroupName UKSRG1 -Name “UKSRGVM01” -Location “UK South” -VirtualNetworkName “UKSVnet1” -SubnetName “vmsubnet2” -addressprefix 10.75.0.0/24 -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

##### Create Azure Bastion Resource #####
$azsubnetname = "AzureBastionSubnet"
$azsubnet = New-AzVirtualNetworkSubnetConfig -Name $azsubnetname -AddressPrefix 10.2.0.0/24
$vnet = New-AzVirtualNetwork -Name "BASVnet1" -ResourceGroupName "BASRG1" -Location "West US" -AddressPrefix 10.2.0.0/16 -Subnet $azsubnet

$pip = New-AzPublicIpAddress -ResourceGroupName "BASRG1" -name "BASPublicIP" -location "West US" -AllocationMethod Static -Sku Standard

New-AzBastion -ResourceGroupName "BASRG1" -Name "REBELBastion" -PublicIpAddress $pip -VirtualNetwork $vnet

##### Create Global VNet Peering between Hub-Skpoke Virtual Networks ######
$vnet1 = Get-AzVirtualNetwork -Name BASVnet1 -ResourceGroupName BASRG1

$vnet2 = Get-AzVirtualNetwork -Name EUSVnet1 -ResourceGroupName EUSRG1

Add-AzVirtualNetworkPeering -Name BASVnet1toEUSVnet1 -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id

Add-AzVirtualNetworkPeering -Name EUSVnet1toBASVnet1 -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id

$vnet3 = Get-AzVirtualNetwork -Name BASVnet1 -ResourceGroupName BASRG1

$vnet4 = Get-AzVirtualNetwork -Name UKSVnet1 -ResourceGroupName UKSRG1

Add-AzVirtualNetworkPeering -Name BASVnet1toUKSVnet1 -VirtualNetwork $vnet3 -RemoteVirtualNetworkId $vnet4.Id

Add-AzVirtualNetworkPeering -Name UKSVnet1toBASVnet1 -VirtualNetwork $vnet4 -RemoteVirtualNetworkId $vnet3.Id