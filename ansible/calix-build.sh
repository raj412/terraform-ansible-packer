#!/bin/bash 
#Litfibre build calix node
cd /infra-ansible

#export ANSIBLE_HOST_KEY_CHECKING=False

. /infra-ansible/functions.sh
#f_add_key

# run ansible
ansible-playbook -i /infra-ansible/inventory-tmp /infra-ansible/calix-build.yml -e 'ansible_python_interpreter=/usr/bin/python3'
