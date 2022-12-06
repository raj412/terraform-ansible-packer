#!/usr/bin/env python3
import os
import sys
import json
import re
from datetime import datetime, time
import lutils as util
import logger as log
import time
import boto3
from botocore.exceptions import ClientError
import shutil

log.set_level('INFO')

##############################################################
# Set the alert in the poller                                #
# Sending a the process id of this process                   #
# Will wait alertpollerwait for the process to finish        #
# If the process disapears and the alert file is still there #
# then it will send alerts to prometheus                     #
##############################################################
import alerts
from datetime import datetime

alertname        = "CalixBackup"
alertdescription = "Calix Backup"
alertstart       = str(datetime.utcnow().isoformat("T") + "Z")
alertsummary     = "Backs up Calix/smx data"
alertmessage     = "Calix manages all broadband OLT an ONT devices"
alerts.create_alert(alertname,alertdescription,alertsummary,alertmessage,alert_level="critical")

########################
# End of alert section #
########################


userName='admin'
password='test123'
calixHome="/opt/PMAPMAA"
calixBackupDir=calixHome + "/backup"
mongoHome=calixHome + "/mongodb"
mongoDumpCmd=mongoHome + "/bin/mongodump "
backupBucket="litfibre-infra"
backupPrefix="calix-backup-archive/"
localBackupRetentionDays=7


calixBackupScript= "/opt/PMAPMAA/bin/activate-db-backup.sh"
if calixBackupScript == None:
        log.write(abort_it=True,level=0,message="Calix backup Script was not found - Aborting")

timeStamp= str(int(time.time()))
if timeStamp == None:
        log.write(abort_it=True,level=0,message="Timestamp is null this must be fixed")

backupTgzFile=timeStamp + '_full.tar.gz'

log.write(level=2,message="Starting Calix Backup")

def prune_local_backups(Days,bDir):
  with os.scandir(bDir) as dir_entries:
    for entry in dir_entries:
      info = entry.stat()
      dAge=(int(timeStamp) - int(info.st_mtime))/86400
      if dAge > Days:
        #try:
        if os.path.isfile(bDir + '/' + entry.name):
          rtn=os.remove(bDir + '/' + entry.name)
          log.write(level=2,message="Backup file %s was removed" %(entry.name))
        else:
          rtn=shutil.rmtree(bDir + '/' + entry.name + '/')
        #except:
        #  e= sys.exc_info()[0]
        #  log.write(abort_it=True,level=0,message="Backup file removal FAILED with the following %s for file %s" % (e,entry.name))
  return True

def upload_file(file_name, bucket, object_name=None, environment='DEV'):
    """
                :param object_name: S3 object name. If not specified then file_name is used
    """
    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = file_name
    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
        put_tags_response = s3_client.put_object_tagging(Bucket=bucket,Key=object_name,
          Tagging={
            'TagSet': [{'Key': 'Env','Value': environment}]})
    except ClientError as e:
        log.write(level=0,message="S3 upload failed - %s" %(e))
        return False
    return True


def get_backup_options():

  backupOptions=  [ "-h 127.0.0.1:4000",
                  "--quiet ",
                  "-u " + userName,
                  "-p " + password,
                  "--db activate",
                  "--authenticationDatabase admin",
                  "-o " + calixBackupDir + "/" + timeStamp
                  ]
  with open(calixBackupScript, 'r') as scriptfile:
    for line in scriptfile:
      if re.search(".*--db activate.*",line):
        bits=line.split(' ')
        for bit in bits:
          if re.search("--exclude.*",bit):
            backupOptions.append(bit)

  return backupOptions

if not util.run_local_cmd('/bin/pgrep -l  mongo','Check that MongoDB is alive'):
  log.write(abort_it=True,level=0,message="ERROR: Mongo backup has failed - MongoDB is not running on this node")
else:
        log.write(level=2,message="Mongo is running on this node")

if not os.path.isdir(calixBackupDir):
  log.write(level=2,message="Creating the mongodb backup directory")
  os.makedirs(calixBackupDir)
  os.chmod(calixBackupDir, 0o755)

backupCommand= mongoDumpCmd

for bopt in get_backup_options():
  backupCommand += bopt + " "

os.chdir(calixBackupDir)

if util.run_local_cmd(backupCommand):
        log.write(level=2,message="Mongo Backup Succeeded")
else:
        log.write(level=0,message="Mongo Backup Failed")

if util.run_local_cmd('cp ' + calixHome + '/bin/calix-activate-version.ini ./' + timeStamp):
        log.write(level=2,message="Copied activate ini file")
else:
        log.write(abort_it=True,level=0,message="activate ini file copy FAILED")

if util.run_local_cmd('tar -czf ' + backupTgzFile + ' ./' + timeStamp):
        log.write(level=2,message="Archive of backup successful")
else:
        log.write(abort_it=True,level=0,message="Archive of backup - FAILED")

#Get the environment value
ienv = util.get_tag_value('Environment')
log.write(level=2,message="This is a %s environment backup" %(ienv))

#send it to S3
if upload_file(backupTgzFile, backupBucket, object_name=backupPrefix + backupTgzFile,environment=ienv):
        log.write(level=2, message="Archive copied to S3 successfully")
else:
        log.write(abort_it=True,level=0,message="Copy of backup to S3 has FAILED")


if not util.run_local_cmd('rm -rf ./' + timeStamp):
        log.write(abort_it=True,level=0,message="Failed to remove the backup directory - %s" %(calixBackupDir + '/' + timeStamp))

log.write(level=2,message="Pruning local backup files over %s days old" %(localBackupRetentionDays))
if prune_local_backups(localBackupRetentionDays,calixBackupDir):
  log.write(level=2,message="Pruning was successful")
else:
        log.write(abort_it=True,level=0,message="Backup pruning - FAILED")


log.write(level=2,message="Backed up data as %s/%s_full.tar.gz" %(calixBackupDir,timeStamp))

###############################################################################
# At this point we can delete the alert file                                  #
# The alert poller will wait to send the alert if the process is still runing # 
###############################################################################

alerts.delete_alert(alertname)