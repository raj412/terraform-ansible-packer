#!/bin/sh

#################################################
# This is a patched recovery script by Litfibre #
#################################################

# This script runs on every mongo node.
# Precondition: it needs startup mongo service before executing this script

#set -x

SCRIPT_NAME=$0
PRGDIR=`dirname "$0"`
PRGDIR=`cd "${PRGDIR}"; pwd`

PMAPMAA_HOME=`cd "${PRGDIR}/.." ; pwd`
MONGO_HOME=${PMAPMAA_HOME}/mongodb
MONGO_BACKUP_FOLDER=${PMAPMAA_HOME}/backup
#source $PRGDIR/env.sh
pass=$(grep 'mongo.password=' ${PMAPMAA_HOME}/pmaa/conf/mongo.properties | cut -d '=' -f2)
INI_FILE=${PMAPMAA_HOME}/bin/calix-activate-version.ini
Mongo_Host=127.0.0.1
#MongoDB_URL="$MONGO_HOME/bin/mongo $Mongo_Host:4000/activate -u activate -p $pass"
db_url=`grep "A_MONGO_URL=" ${PMAPMAA_HOME}/pmaa/conf/mongo.properties | awk -F'//' '{print $2}'`
# SP Change
connect_db_url="$MONGO_HOME/bin/mongo $db_url"

if [ ! -d ${MONGO_BACKUP_FOLDER} ]; then
    echo "Folder $MONGO_BACKUP_FOLDER does not exist. Please check it."
    exit 1
fi

usage(){
    echo "===== Usage ====="
    echo "Usage:"
    echo "    $SCRIPT_NAME {backup file name, e.g. activate.yyyymmddHHMMSS.tar.gz}, you can run command \"ll ${MONGO_BACKUP_FOLDER}\" get all available backup file"
}

if [ "x$1" == "x" ]; then
        echo "Please input the backup file name, you can run command \"ll ${MONGO_BACKUP_FOLDER}\" to get all available backup file"
        exit 1
fi

usage

#Need check whether the mongo started. If not, it needs start it first and shutdown it after the restore completed.
vShutdownMongo="false"
checkAndWaitMongo(){
  local ret=0
  `cd $MONGO_HOME/bin; nohup ./startup.sh >/dev/null 2>&1 &`
  starting_proc_chk "MongoDB    " "mongodb.conf" 5 10
  let ret+=$?
  return $ret
}

chk_mongo_command="`ps -ef|grep mongodb.conf|grep -v grep|head -1|awk '{print $2}'`"
if [ -z "$chk_mongo_command" ] ; then
    echo "============================================================="
    echo "MongoDB not startup, it needs startup it first, please wait.."
    echo "============================================================="
    checkAndWaitMongo
    if [ $? -gt 0 ]; then
     echo " Error. MongoDB startup failed!"
     exit 1
    fi
    vShutdownMongo="true"
fi


##
# Database restore works only on same version of SMx
# Check activateVersion in collection:ActivateVersion is same as baseline in calix-activate-version.ini
# If Version does not match restore should be stopped
##

# SP Change
#activate_version=`${db_url} --quiet --eval "db.ActivateVersion.find()" | grep -F '"activateVersion" :' |  cut -d "#" -f 1 |  cut -d ":" -f 3 | tr -d '"' | xargs`
activate_version=`${connect_db_url} --quiet --eval "db.ActivateVersion.find()" | grep -F '"activateVersion" :' |  cut -d "#" -f 1 |  cut -d ":" -f 3 | tr -d '"' | xargs`
echo "Activate Version in Database is : $activate_version"

ini_activate_version=`grep -F "release_version=" $INI_FILE |  cut -d '=' -f 2`
echo "Activate Version in ini file is : $ini_activate_version"

if [[ $activate_version != $ini_activate_version ]]; then
  echo "SMx allows the restoration of a database when the SMx version of the database backup is the same as the SMx version you are restoring the database to."
  exit 1
else
  echo "Initiate database restore ..."
fi

BACKUP_FILE="${MONGO_BACKUP_FOLDER}/$1"
BACKUP_FOLD=$(echo ${BACKUP_FILE} | cut -d '_' -f1)
if [ ! -f ${BACKUP_FILE} ]; then
    echo "File ${BACKUP_FILE} for backup does not exist. Please check it."
    exit 1
fi

cd ${MONGO_BACKUP_FOLDER}
rm -rf ./activate
tar -xzvf ${BACKUP_FILE}

cd ${MONGO_HOME}
MongoDB="${MONGO_HOME}/bin/mongo $db_url"

PrimaryQuery=$(echo "db.isMaster()" | ${MongoDB} --shell)
PrimaryInfo=`echo "${PrimaryQuery}" | grep primary | awk -F "\"" '{print $4}'`
echo "PrimaryInfo: ${PrimaryInfo}"

#delete all collectons for mongorestore
MasterMongo="${MONGO_HOME}/bin/mongo $db_url"
ShowCollectionMsg=$(echo "show collections" | ${MasterMongo} )
i=3
CollectionName=""
while true
do
  CollectionName=$(echo "${ShowCollectionMsg}" | sed -n ${i}p)
  if [ "${CollectionName}" = "bye" ];then
    break
  fi
  if [[ "${CollectionName}" != "system.indexes" && "${CollectionName}" != "ClusterNode" && "${CollectionName}" != "ActivateVersion" ]];then
    echo "drop ${CollectionName}..."
    echo "db.${CollectionName}.drop()" | ${MasterMongo} | sed -n 3p
  fi
  let i+=1
done

#$MONGO_HOME/bin/mongorestore -h ${PrimaryInfo} -u activate -p pmaa123 -d activate --drop --dir ${MONGO_BACKUP_FOLDER}/activate --noIndexRestore
activate_folder=${BACKUP_FOLD}/activate
db_collections_in_gz_format=$(find ${activate_folder} -name '*.gz' | wc -l)
if [ ${db_collections_in_gz_format} -gt 0 ];then
        $MONGO_HOME/bin/mongorestore --gzip -h 127.0.0.1:4000  -u admin -p test123 --drop --nsExclude='*ClusterNode' --nsExclude='*ActivateVersion' --authenticationDatabase admin  ${BACKUP_FOLD}
else
        $MONGO_HOME/bin/mongorestore -h 127.0.0.1:4000  -u admin -p test123 --drop --nsExclude='*ClusterNode' --nsExclude='*ActivateVersion' --authenticationDatabase  admin  ${BACKUP_FOLD}
mv ${BACKUP_FOLD}/calix-activate-version.ini ${PMAPMAA_HOME}/bin/
fi
rm -rf ${BACKUP_FOLD}

echo "==========================="
echo "MongoDB will clear DeviceStatusReactor."
echo "==========================="
${MasterMongo} --eval  "db.DeviceStatusReactor.remove({})"

instance_id=$(echo "db.InstanceId.find({})[0].instanceId" | ${MasterMongo} --shell)
instanceId=$(echo $instance_id|rev|cut -d ' ' -f2|rev)

LICENSING_FILE="${PMAPMAA_HOME}/bin/license_accounting.conf"
sed -i '/MachineId:/d' ${LICENSING_FILE}
echo "MachineId: $instanceId" >>${LICENSING_FILE}

if [[ "x$vShutdownMongo" == "xtrue" ]]; then
  echo "==========================="
  echo "MongoDB will shutdown now."
  echo "==========================="
  `cd $MONGO_HOME/bin; nohup ./stop.sh >/dev/null 2>&1 &`

fi

echo  "Updating SubscriberServices view started"
${MONGO_HOME}/bin/mongo $db_url --quiet  $PMAPMAA_HOME/bin/subscriber_view.js
echo  "Updating SubscriberServices view finished"


echo "Restored data from ${BACKUP_FILE} sucessfully."