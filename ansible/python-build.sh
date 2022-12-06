#!/bin/bash
# Litfibre build python node
cd /infra-ansible

. /infra-ansible/functions.sh

# run ansible
ansible-playbook -i /infra-ansible/inventory-tmp /infra-ansible/python-build.yml
