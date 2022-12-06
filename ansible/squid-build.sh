#!/bin/bash
# Litfibre build squid node
cd /infra-ansible

#export ANSIBLE_HOST_KEY_CHECKING=False

. /infra-ansible/functions.sh

# run ansible
ansible-playbook -i /infra-ansible/inventory-tmp /infra-ansible/squid-build.yml
