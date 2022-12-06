#!/bin/bash
pwdir=`pwd`
basedir=`dirname $pwdir`
source ${basedir}/set-env.sh
packer build -var-file="${basedir}/subnet.variables.pkr.hcl" -var-file="${basedir}/ubuntu.variables.pkr.hcl" ${basedir}/packer/config/ubuntu-basic.pkr.hcl
