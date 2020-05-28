################ Create New RG ####################

New-AzResourceGroup -Name REBELRG1 -Location “East US”

################ Create Firewall VNet ###############

$fwsubn1 = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix 10.0.0.0/24

$eusfwvnet = New-AzVirtualNetwork -Name EUSFWVnet1 -ResourceGroupName REBELRG1 -Location "East US" -AddressPrefix 10.0.0.0/16 -Subnet $fwsubn1

############### Create Production VNet ################

$worksubn1 = New-AzVirtualNetworkSubnetConfig -Name WorkSubnet -AddressPrefix 10.2.0.0/24

$workvnet = New-AzVirtualNetwork -Name EUSWorkVnet1 -ResourceGroupName REBELRG1 -Location "East US" -AddressPrefix 10.2.0.0/16 -Subnet $worksubn1

############## VNet Peering ####################

Add-AzVirtualNetworkPeering -Name FWtoWork -VirtualNetwork $eusfwvnet -RemoteVirtualNetworkId $workvnet.Id

Add-AzVirtualNetworkPeering -Name WorktoFW -VirtualNetwork $workvnet -RemoteVirtualNetworkId $eusfwvnet.Id

############# Create Azure Firewall #################

$fwip1 = New-AzPublicIpAddress -Name EUSFWIP1 -ResourceGroupName REBELRG1 -Location "East US" -AllocationMethod Static -Sku Standard

$EUSFW = New-AzFirewall -Name EUSFW01 -ResourceGroupName REBELRG1 -Location "East US" -VirtualNetworkName EUSFWVnet1 -PublicIpName EUSFWIP1

$EUSFWPrivateIP = $EUSFW.IpConfigurations.privateipaddress
$EUSFWPrivateIP

############# Create VM ############################

$mylogin = Get-Credential

New-AzVm -ResourceGroupName REBELRG1 -Name “REBELTVM01” -Location “East US” -VirtualNetworkName “EUSWorkVnet1” -SubnetName “WorkSubnet” -addressprefix 10.2.0.0/24 -PublicIpAddressName “REBELVM01IP1” -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

############# Create Default Route ####################

$routetable1 = New-AzRouteTable -Name REBELdefaultroute -ResourceGroupName REBELRG1 -Location "East US" -DisableBgpRoutePropagation

Get-AzRouteTable -ResourceGroupName REBELRG1 -Name REBELdefaultroute | Add-AzRouteConfig -Name tofirewall -AddressPrefix 0.0.0.0/0 -NextHopType "VirtualAppliance" -NextHopIpAddress $EUSFWPrivateIP | Set-AzRouteTable

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $workvnet -Name WorkSubnet -AddressPrefix 10.2.0.0/24 -RouteTable $routetable1 | Set-AzVirtualNetwork

############# Find Public IP of Firewall #################

Get-AzPublicIpAddress -Name EUSFWIP1 -ResourceGroupName REBELRG1

############# Find Private IP of VM ####################

Get-AzNetworkInterface -ResourceGroupName REBELRG1 | ForEach { $Interface = $_.Name; $IPs = $_ | Get-AzNetworkInterfaceIpConfig | Select PrivateIPAddress; Write-Host $Interface $IPs.PrivateIPAddress }

############# Create NAT Rule ##################

$fwnatrule1 = New-AzFirewallNatRule -Name "DNAT1" -Protocol "TCP" -SourceAddress "*" -DestinationAddress "52.191.101.132" -DestinationPort "3389" -TranslatedAddress "10.2.0.4" -TranslatedPort "3389"

$fwnatrulecollection1 = New-AzFirewallNatRuleCollection -Name RDPAccess -Priority 200 -Rule $fwnatrule1

$EUSFW.NatRuleCollections = $fwnatrulecollection1

Set-AzFirewall -AzureFirewall $EUSFW
