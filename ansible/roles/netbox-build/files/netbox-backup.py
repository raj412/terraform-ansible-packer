#!/usr/bin/env python3

from datetime import datetime, time
import time
import v2_lutils as util
import logging as log
import sys

#############
# Constants #
#############
c_log_level= log.INFO 
c_app_name= "Netbox"
c_dest_bucket= 'litfibre-infra'
c_dest_prefix= 'netbox-backup-archive'
c_backup_dir= 'D:/Data/MSSQL-backup/'             
c_log_file=   '/opt/management/last_backup.log'



#################
# Setup Logging #
#################

log.basicConfig(format='%(asctime)s %(levelname)s:%(message)s', 
                datefmt='%Y-%d-%mT%H:%M:%S%z',
                handlers=[
                  log.FileHandler(c_log_file,mode='w+'),
                  log.StreamHandler()
                ],
                level=c_log_level)

log.info("Starting Postgres Backup")

##############################################################
# Set the alert in the poller                                #
# Sending a the process id of this process                   #
# Will wait alertpollerwait for the process to finish        #
# If the process disapears and the alert file is still there #
# then it will send alerts to prometheus                     #
##############################################################
import v2_alerts as alerts
#from datetime import datetime

alertname        = "NetboxBackup"
alertdescription = "Netbox Backup"
alertstart       = str(datetime.utcnow().isoformat("T") + "Z")
alertsummary     = "Backs up Netbox config data"
alertmessage     = "Netbox data is important, but not critical"
alerts.create_alert(alertname,alertdescription,alertsummary,alertmessage,alert_level="warning")

########################
# End of alert section #
########################

timeStamp= str(int(time.time()))
if timeStamp == None:
        log.critical("Timestamp is null this must be fixed")
        sys.exit(1)

backupDest=c_dest_prefix + '/' + 'postgresql_' + timeStamp + '_full.gz'

log.info("Writing backup to s3://%s/%s" %(c_dest_bucket,backupDest))

backupCmd= 'sudo su - postgres -c pg_dumpall|gzip -c'

l_env= util.get_tag_value("Environment")
if(util.run_local_cmd_to_s3(cmd=backupCmd,desc="Backup Netbox",bucket=c_dest_bucket,dest=backupDest,environment=l_env)):
  log.info("Backup completed successfully")
else:
  log.critical("Backup failed")
  sys.exit(1)

###############################################################################
# At this point we can delete the alert file                                  #
# The alert poller will wait to send the alert if the process is still runing # 
###############################################################################

alerts.delete_alert(alertname)