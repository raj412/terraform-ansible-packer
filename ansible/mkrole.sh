#!/bin/bash


ROLENAME=$1
ROLEDIR=roles
OWNER=root
GROUP=root
SHORTNAME=`echo ${ROLENAME}|awk -F- '{print $1}'`
HOMEDIR=`pwd`
TYPEN=`echo ${ROLENAME}|awk -F- '{print $2}'`
LOCAL='N'

function local {
	cat /etc/passwd |grep sperez 1>/dev/null 2>&1
	if [ $? == 0 ];then
		export OWNER=sperez
		export GROUP=sperez
	fi
}

local

if [ "${TYPEN}" != "build" ];then
	printf "\nERROR: Role name should be name-build\n\n"
	exit 1
fi

if [ "$ROLENAME" == "" ];then
   printf "\nERROR: Need to specify a role name\n\n"
   exit 1
fi
if [ -d ./roles/$ROLENAME ];then
   printf "\nERROR:Role %s already exists\n\n" $ROLENAME
   exit 1
fi
mkdir ./$ROLEDIR/$ROLENAME
cd ./$ROLEDIR/$ROLENAME
for mDir in files handlers meta templates tasks vars
do
	mkdir $mDir
	cd $mDir
	touch main.yml
	chown $OWNER:$GROUP main.yml
	printf "#\n" >> main.yml
	printf "# role $ROLENAME\n" >>main.yml
	printf "# $mDir file\n" >>main.yml
	printf "#\n\n" >>main.yml
	cd ..
done
chown -R $OWNER:$GROUP $HOMEDIR/$ROLEDIR

cd $HOMEDIR

SHORTNAME=`echo ${ROLENAME}|awk -F- '{print $1}'`

cat << EOF >${ROLENAME}.sh
#!/bin/bash
# Litfibre build ${SHORTNAME} node
cd /infra-ansible

#export ANSIBLE_HOST_KEY_CHECKING=False

. /infra-ansible/functions.sh

# run ansible
ansible-playbook -i /infra-ansible/inventory-tmp /infra-ansible/${ROLENAME}.yml
EOF

chown ${OWNER}:${GROUP} ${ROLENAME}.sh
chmod 0755 ${ROLENAME}.sh


cat << EOF >${ROLENAME}.yml
#
# ${ROLENAME}.yml
#

# Set machine up for development
- name: ${SHORTNAME} Build
  hosts: ['linux']
  connection: local
  become: true
  remote_user: ubuntu
  become_user: root
  roles:
     - ${ROLENAME}
  strategy: free
EOF

chown ${OWNER}:${GROUP} ${ROLENAME}.yml

chmod 0755 ${ROLENAME}.yml
