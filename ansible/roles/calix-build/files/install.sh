#!/bin/bash

export INSTALL_WITH_ENVIRONMENT=true
export ENVIRONMENT_TYPE=Prod

export inst='install.bin'
export atoken=`cat /opt/calix/deploy/calix-account-key.txt`
export calixip=`host $(hostname) |awk '{print $4}'`
export hn=`host $(hostname)|awk -F. '{print $1}'`
export fixhn=${hn}-fixed
export fixedDevice=`ip addr |grep "^3:"|awk -F: '{print $2}'|tr -d ' '`
./$inst -n -b $fixedDevice -i $calixip -f -k $atoken -q Litfibre -w

