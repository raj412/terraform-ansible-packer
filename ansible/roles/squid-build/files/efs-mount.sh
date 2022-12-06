#!/bin/bash

#Mount EFS File
mount_path="/etc/squid/squid-conf"
Secret_NAME="dev/aws/efs/squiddns"
DNS=`aws secretsmanager get-secret-value  --secret-id $Secret_NAME --region=eu-west-2 --query 'SecretString' --output text | jq -r '.SquidDNS'`

#Created directry 
mkdir -p $mount_path
#Mount efs
mountpoint -q $mount_path || `mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $DNS:/ $mount_path`