#!/bin/bash
# Litfibre build netbox node
cd /infra-ansible

. /infra-ansible/functions.sh

# run ansible
ansible-playbook -i /infra-ansible/inventory-tmp /infra-ansible/netbox-build.yml
