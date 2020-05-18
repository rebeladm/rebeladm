################# Create Azure Firewall Resource Group ####################

Connect-AzAccount

New-AzResourceGroup -Name REBELRG1 -Location “East US”

################# Create VNet in Firewall Network #########################

$fwsubn1 = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix 10.0.0.0/24

$gwsubn1 = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix 10.0.1.0/24

$eusfwvnet = New-AzVirtualNetwork -Name EUSFWVnet1 -ResourceGroupName REBELRG1 -Location "East US" -AddressPrefix 10.0.0.0/16 -Subnet $fwsubn1,$gwsubn1

################# Create VPN Gateway in Firewall Network ##################

$gatewayip1 = New-AzPublicIpAddress -Name EUSFWVnet1GW1 -ResourceGroupName REBELRG1 -Location "East US" -AllocationMethod Dynamic

$fwvnet1 = Get-AzVirtualNetwork -Name EUSFWVnet1 -ResourceGroupName REBELRG1
$fwgwsubnet1 = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $eusfwvnet
$eusfwgw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name eusfwgw1ipconf1 -Subnet $fwgwsubnet1 -PublicIpAddress $gatewayip1

New-AzVirtualNetworkGateway -Name EUSFWGW1 -ResourceGroupName REBELRG1 -Location "East US" -IpConfigurations $eusfwgw1ipconf1 -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1

################# Create Azure Firewall ##########################

$fwip1 = New-AzPublicIpAddress -Name EUSFWIP1 -ResourceGroupName REBELRG1 -Location "East US" -AllocationMethod Static -Sku Standard

$EUSFW = New-AzFirewall -Name EUSFW01 -ResourceGroupName REBELRG1 -Location "East US" -VirtualNetworkName EUSFWVnet1 -PublicIpName EUSFWIP1

$EUSFWPrivateIP = $EUSFW.IpConfigurations.privateipaddress
$EUSFWPrivateIP

################ Create Azure Firewall Rule to Allow RDP traffic to Workloads network from Remote Network ############################

$fwrule1 = New-AzFirewallNetworkRule -Name "AllowRDP" -Protocol TCP -SourceAddress 10.1.0.0/24 -DestinationAddress 10.2.0.0/16 -DestinationPort 3389

$fwrulecollection = New-AzFirewallNetworkRuleCollection -Name RDPAccess -Priority 100 -Rule $fwrule1 -ActionType "Allow"

$EUSFW.NetworkRuleCollections = $fwrulecollection

Set-AzFirewall -AzureFirewall $EUSFW

#################### Create Resourse Group for Remote network ##############################

New-AzResourceGroup -Name REBELRG2 -Location “UK South”

#################### Create VNet in Remote network #########################################

$subn2 = New-AzVirtualNetworkSubnetConfig -Name VMNet1 -AddressPrefix 10.1.0.0/24

$gwsubn2 = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix 10.1.1.0/24

$uksouthvnet = New-AzVirtualNetwork -Name UKSVnet1 -ResourceGroupName REBELRG2 -Location "UK South" -AddressPrefix 10.1.0.0/16 -Subnet $subn2,$gwsubn2

################### Create VPN Gateway in Remote network ################################

$gatewayip2 = New-AzPublicIpAddress -Name UKSVnet1GW1 -ResourceGroupName REBELRG2 -Location "UK South" -AllocationMethod Dynamic

$vnet2 = Get-AzVirtualNetwork -Name UKSVnet1 -ResourceGroupName REBELRG2
$gwsubnet2 = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet2
$uksgw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name uksgw1ipconf1 -Subnet $gwsubnet2 -PublicIpAddress $gatewayip2

New-AzVirtualNetworkGateway -Name UKSGW1 -ResourceGroupName REBELRG2 -Location "UK South" -IpConfigurations $uksgw1ipconf1 -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1

################### Create Resourse group for workloads network #######################

New-AzResourceGroup -Name REBELRG3 -Location “East US”

################### Create VNet in workloads network ###########################

$subn3 = New-AzVirtualNetworkSubnetConfig -Name VMNet2 -AddressPrefix 10.2.0.0/24

$gwsubn3 = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix 10.2.1.0/24

$workloadvnet = New-AzVirtualNetwork -Name EUSFVnet1 -ResourceGroupName REBELRG3 -Location "East US" -AddressPrefix 10.2.0.0/16 -Subnet $subn3,$gwsubn3

################## Create VPN Connections ################################

$fwgw = Get-AzVirtualNetworkGateway -Name EUSFWGW1 -ResourceGroupName REBELRG1
$uksgw = Get-AzVirtualNetworkGateway -Name UKSGW1 -ResourceGroupName REBELRG2

New-AzVirtualNetworkGatewayConnection -Name fwgwtouksgw -ResourceGroupName REBELRG1 -VirtualNetworkGateway1 $fwgw -VirtualNetworkGateway2 $uksgw -Location "East US" -ConnectionType Vnet2Vnet -SharedKey 'Rebel123'

New-AzVirtualNetworkGatewayConnection -Name uksgwtofwgw -ResourceGroupName REBELRG2 -VirtualNetworkGateway1 $uksgw -VirtualNetworkGateway2 $fwgw -Location "UK South" -ConnectionType Vnet2Vnet -SharedKey 'Rebel123'

############### Create VNet Peering ######################################

Add-AzVirtualNetworkPeering -Name FWtoWorkloads -VirtualNetwork $eusfwvnet -RemoteVirtualNetworkId $workloadvnet.Id -AllowGatewayTransit
Add-AzVirtualNetworkPeering -Name WorkloadstoFW -VirtualNetwork $workloadvnet -RemoteVirtualNetworkId $eusfwvnet.Id -AllowForwardedTraffic -UseRemoteGateways

############### Create routing ##################

$routetable1 = New-AzRouteTable -Name REBELRouteTable1 -ResourceGroupName REBELRG1 -Location "East US"

Get-AzRouteTable -ResourceGroupName REBELRG1 -Name REBELRouteTable1 | Add-AzRouteConfig -Name routetoworkloads -AddressPrefix 10.2.0.0/16 -NextHopType "VirtualAppliance" -NextHopIpAddress $EUSFWPrivateIP | Set-AzRouteTable

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $eusfwvnet -Name "GatewaySubnet" -AddressPrefix 10.0.1.0/24 -RouteTable $routetable1 | Set-AzVirtualNetwork

$routetable2 = New-AzRouteTable -Name REBELdefaultroute -ResourceGroupName REBELRG1 -Location "East US" -DisableBgpRoutePropagation

Get-AzRouteTable -ResourceGroupName REBELRG1 -Name REBELdefaultroute | Add-AzRouteConfig -Name tofirewall -AddressPrefix 0.0.0.0/0 -NextHopType "VirtualAppliance" -NextHopIpAddress $EUSFWPrivateIP | Set-AzRouteTable

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $workloadvnet -Name VMNet2 -AddressPrefix 10.2.0.0/24 -RouteTable $routetable2 | Set-AzVirtualNetwork

################ Create VM for testing #########################

$mylogin = Get-Credential

New-AzVm -ResourceGroupName REBELRG3 -Name “REBELTVM01” -Location “East US” -VirtualNetworkName “EUSFVnet1” -SubnetName “VMNet2” -addressprefix 10.2.0.0/24 -PublicIpAddressName “REBELVM01IP1” -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

New-AzVm -ResourceGroupName REBELRG2 -Name “REBELTVM02” -Location “UK South” -VirtualNetworkName “UKSVnet1” -SubnetName “VMNet1” -addressprefix 10.1.0.0/24 -PublicIpAddressName “REBELVM02IP1” -OpenPorts 3389 -Image win2019datacenter -Size Standard_D2s_v3 -Credential $mylogin

############### Additonal Firewall rule to allow RDP traffic from workloads network to remote network ################################

$fwrule2 = New-AzFirewallNetworkRule -Name "AllowRDPtoRemote" -Protocol TCP -SourceAddress 10.2.0.0/24 -DestinationAddress 10.1.0.0/24 -DestinationPort 3389
$fwrulecollection2 = New-AzFirewallNetworkRuleCollection -Name RDPAccesstoRemote -Priority 200 -Rule $fwrule2 -ActionType "Allow"

$EUSFW.NetworkRuleCollections = $fwrulecollection, $fwrulecollection2

Set-AzFirewall -AzureFirewall $EUSFW