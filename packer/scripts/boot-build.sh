#!/bin/bash

iface='unknown'
uname -a|grep -i ubuntu 1>/dev/null 2>&1
if [ $? == 0 ];then
  iface='ens5'
  iOs='ubuntu'
elif [ -f /etc/redhat-release ];then
  cat /etc/redhat-release |grep -i centos 1>/dev/null 2>&1
  if [ $? == 0 ];then
    iface='eth0'
    iOs='centos-7'
  fi
else
  logger OS not identified ERROR
  exit 1
fi

REGION="`wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

function f_clone_repo
{
  logger Cloning Ansible
  if [ ! -d /root/.ssh ];then
    mkdir /root/.ssh
  fi
  iEnv=`f_get_tag Environment|tr '[:upper:]' '[:lower:]'`
  aws secretsmanager get-secret-value --region ${REGION} --secret-id ${iEnv}/deploy/key|jq -r .SecretString>/root/.ssh/id_ed25519 
  chmod 600 /root/.ssh/id_ed25519
  ssh-keyscan -H github.com > /root/.ssh/known_hosts
  if [ ! -d /infra-ansible ];then
    cd /
    git clone git@github.com:Lit-Fibre/infra-ansible.git
    if [ $? == 0 ];then
      logger Ansible Clone succeded
      chmod 700 /infra-ansible
    else
      logger Ansible Clone FAILED
    fi
  fi
}

function f_get_tag
{
  TAG_NAME=$1
  INSTANCE_ID="`wget -qO- http://instance-data/latest/meta-data/instance-id`"
  TV="`aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=${TAG_NAME}" --region ${REGION} --output=text | cut -f5`"
  echo ${TV}
}

export iEnv=`f_get_tag Environment|tr '[:upper:]' '[:lower:]'`

if [ ! -f "/opt/build-state/initial-build" ];then
  while true
  do
    export hn=`host $(ip addr |grep inet|grep ${iface}|awk '{print $2}'|awk -F/ '{print $1}')|awk '{print $5}'|awk -F. '{print $1}'`
    echo "node name = $hn" |grep "\-${iEnv}"
    if [ $? == 0 ];then
      break
    fi
    logger Waiting for DNS to come on-line
    sleep 10
  done
  logger DNS is returning $hn
  logger Starting basic node build
  f_clone_repo
  /infra-ansible/lf-linux-basic-node-${iOs}.sh $hn
  if [ $? == 0 ];then
    logger Initial build succeeded
    touch /opt/build-state/initial-build
  else
    logger Initial build FAILED
    exit 1
  fi
fi

#Get the list of apps read the local App tags from the instance
TAG_VALUE="`f_get_tag App`"
aws configure set default.region ${REGION}
for role in $TAG_VALUE
do
  if [ ! -f "/opt/build-state/${role}-build" ];then
    logger Starting ${role} build
    /infra-ansible/${role}-build.sh
    if [ $? == 0 ];then
      logger ${role} build succeeded
      touch /opt/build-state/${role}-build
    else
      logger ${role}-build FAILED
      exit 1
    fi
  fi
done
logger boot-build succeeded
exit 0