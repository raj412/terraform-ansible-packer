#!/bin/bash

REGION="`wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

function f_get_tag
{
  TAG_NAME=$1
  INSTANCE_ID="`wget -qO- http://instance-data/latest/meta-data/instance-id`"
  TV="`aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=${TAG_NAME}" --region ${REGION} --output=text | cut -f5`"
  echo ${TV}
}
iEnv=`f_get_tag Environment|tr '[:upper:]' '[:lower:]'`
if [ "$iEnv" != "dev" ];then
    sed -i 's/lab/prod/g' /opt/PMAPMAA/bin/license_accounting.conf
else
    echo "it's DEV calix"
fi