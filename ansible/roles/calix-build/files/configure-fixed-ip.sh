#!/bin/bash

# debug
set +x

# exit on any error
set -eo pipefail

logger Starting network file configuration

# initialise routing table id
export tableId=0

# This gets the device names
function get_device_name {
    # first option is the index of the device to return
    val=$1
    let dIndex='val+2'
    devName=`ip addr |grep -E "^${dIndex}:"|awk -F: '{print $2}'|tr -d ' '`
    echo $devName
}

# Query the instance for the subnet cidr based on an index
function get_subnet_cidr {
    val=$1
    #get mac for lookup
    queryMac=`ip addr |grep -A1 "^$((val+2)):" |tail -1|awk '{print $2}'`
    echo `wget -qO- http://instance-data/latest/meta-data/network/interfaces/macs/${queryMac}/subnet-ipv4-cidr-block`
}

# calculate the gateway address from the subnet cidr
function get_gateway_addr {
    subnetCidr=$1
    echo `echo $subnetCidr|awk -F/ '{split($1,a,"."); print a[1]"."a[2]"."a[3]"."a[4] +1}'`
}

# query the instance tags for the fixed IP
function get_tag {
    tagName=$1
    instanceId="`wget -qO- http://instance-data/latest/meta-data/instance-id`"
    region="`wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
    tagData=`aws ec2 describe-tags --filters "Name=resource-id,Values=$instanceId" "Name=key,Values=$tagName" --region $region --output=text | cut -f5`
    if [ "$tagData" == "" ];then
        echo ERROR: $tagName is not set
        exit 1
    fi
    echo $tagData
}

function get_netmask {
    cidr=$1
    maskkWidthIndex=0
    maskWidth=32
    # Make an Array for the binary string
    declare -a binNetMask

    # Create the binary Array with binary values
    while true
    do
        if [ $cidr -le 0 ];then
            binNetMask[$maskWidthIndex]="0"
        else
            binNetMask[$maskWidthIndex]="1"
        fi
        let cidr='cidr - 1'
        let maskWidthIndex='maskWidthIndex + 1'
        if [ $maskWidthIndex -eq $maskWidth ];then
            break
        fi
    done

    sindex=0
    bbyte1=""
    bbyte2=""
    bbyte3=""
    bbyte4=""

    # parse each netmask value and convert it to decimal
    while true
    do
        if [ $sindex -ge 0 ] && [ $sindex -lt 8 ];then
            bbyte1="${bbyte1}${binNetMask[$sindex]}"
        fi
        if [ $sindex -eq 8 ];then
            bbyte1=$((2#$bbyte1))
        fi

        if [ $sindex -ge 8 ] && [ $sindex -lt 16 ];then
            bbyte2="${bbyte2}${binNetMask[$sindex]}"
        fi
        if [ $sindex -eq 16 ];then
            bbyte2=$((2#$bbyte2))
        fi

        if [ $sindex -ge 16 ] && [ $sindex -lt 24 ];then
            bbyte3="${bbyte3}${binNetMask[$sindex]}"
        fi
        if [ $sindex -eq 24 ];then
            bbyte3=$((2#$bbyte3))
        fi

        if [ $sindex -ge 24 ] && [ $sindex -lt 32 ];then
            bbyte4="${bbyte4}${binNetMask[$sindex]}"
        fi
        if [ $sindex -eq 32 ];then
            bbyte4=$((2#$bbyte4))
            break
        fi

        let sindex='sindex+1'
    done
    echo "${bbyte1}.${bbyte2}.${bbyte3}.${bbyte4}"
}

function write_fixed_network_config {
    iP=$1
    scidr=$2
    device=$3
    outPath=/etc/sysconfig/network-scripts/ifcfg-${device}

    # get the cidr
    cidrNum=`echo $scidr|awk -F/ '{print $2}'`

    echo "BOOTPROTO=none" >$outPath
    echo "IPADDR=$iP"     >>$outPath
    echo "NETMASK=`get_netmask ${cidrNum}`" >>$outPath
    echo "DEVICE=$device" >>$outPath
}

######################
# Script starts here #
######################

# Set the default variables
defaultTableId=0
defaultDevice=`get_device_name $defaultTableId`
defaultIp=`wget -qO- http://instance-data/latest/meta-data/local-ipv4`
defaultSubnetCidr=`get_subnet_cidr $defaultTableId`
defaultGateway=`get_gateway_addr $defaultSubnetCidr`
defaultRouteFile=/etc/sysconfig/network-scripts/route-${defaultDevice}
defaultRuleFile=/etc/sysconfig/network-scripts/rule-${defaultDevice}

# Set the fixed IP variable
fixedTableId=1
fixedDevice=`get_device_name $fixedTableId`
fixedIp=`get_tag FixedIP`
fixedSubnetCidr=`get_subnet_cidr $fixedTableId`
fixedGateway=`get_gateway_addr $fixedSubnetCidr`
fixedRouteFile=/etc/sysconfig/network-scripts/route-${fixedDevice}
fixedRuleFile=/etc/sysconfig/network-scripts/rule-${fixedDevice}

# Write out the fixed Network config
write_fixed_network_config ${fixedIp} ${fixedSubnetCidr} ${fixedDevice}

# restart the network stack to bring it up
#systemctl restart network

#Setup default route for fixedIP subnet
echo "default via ${fixedGateway} dev ${fixedDevice} proto static metric 101" > "${fixedRouteFile}"
#ip route add default via 172.18.7.1 dev eth1 proto static metric 101

# setup the separate routing table to answer through default interface
echo "${defaultSubnetCidr} dev ${defaultDevice} table 1" > "${defaultRouteFile}"
#ip route add ${defaultSubnetCidr} dev ${defaultDevice} table 1 

echo "0/0 via ${defaultGateway} dev ${defaultDevice} table 1" >> "${defaultRouteFile}"
#ip route add 0/0 via ${defaultGateway} dev ${defaultDevice} table 1

# set the separate routing table to answer through fixedIP interface
echo "${fixedSubnetCidr} dev ${fixedDevice} table 2" >> "${fixedRouteFile}"
#ip route add ${fixedSubnetCidr} dev ${fixedDevice} table 2

#setup the default route to the table
echo "0/0 via ${fixedGateway} dev ${fixedDevice} table 2" >> "${fixedRouteFile}"
#ip route add 0/0 via ${fixedDevice} dev ${fixedDevice} table 2

# route packets with source address aws default ip through table 1
echo "from ${defaultIp} table 1 pref 10001" > "${defaultRuleFile}"
#ip rule add from ${defaultIp} table 1 pref 10001

# route packets with source address fixed ip through table 2
echo "from ${fixedIp} table 2 pref 10002" > "${fixedRuleFile}"
#ip rule add from ${fixedIp} table 2 pref 10002

logger Finished network file configuration
logger Restarting all networking
systemctl restart network
logger Completed network configuration
