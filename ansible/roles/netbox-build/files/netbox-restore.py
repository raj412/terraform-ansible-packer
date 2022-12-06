#!/usr/bin/env python3

import v2_lutils as util
import logging as log
import argparse
import sys
import os

#############
# Constants #
#############
c_log_level= log.INFO
c_app_name= "Netbox"
c_source_bucket= 'litfibre-infra'
c_source_prefix= 'netbox-backup-archive'
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

log.info("Starting Netbox Postgres Restore")

appName= "Netbox"
destBucket= 'litfibre-infra'
destPrefix= 'netbox-backup-archive'
recoverCmd= 'gunzip |sudo su - postgres -c psql'
iEnv= util.get_tag_value('Environment').lower()

# Read the args
setArgs= argparse.ArgumentParser(description="This command will recover %s using an archive stored on S3" %(appName))
setArgs.add_argument('-l','--list',action='store_true',
                     help='Optional - List the last 10 backups stored on S3')
setArgs. add_argument('-f','--file',action='store',dest='archive_name',
                     help='Optional - Name of the S3 archive to recover')
setArgs.add_argument('-r','--recover',action='store_true',
                     help='Optional - Recover the last production backup')
setArgs.add_argument('-y','--yes',action='store_true',
                     help='Optional - Run the command with no prompts')

args= setArgs.parse_args()
list_flag= args.list
archive_name=args.archive_name
prod_flag= args.recover
yes_flag= args.yes

# List option selected 
if ((list_flag == True) and ((archive_name != None) or (prod_flag == True))):
  log.critical("The list archive option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# Recover option selected 
if((prod_flag == True) and ((archive_name != None) or (list_flag == True))):
  log.critical("The recover option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# file option selected
if((archive_name != None) and ((prod_flag == True) or (list_flag == True))):
  log.critical("The file option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# No options selected
if ((list_flag == False) and (archive_name == None) and (prod_flag == False)):
  setArgs.print_help()
  sys.exit(1)

log.debug("list backup files = %s" %(list_flag))
log.debug("Archive name = %s" %(archive_name))
log.debug("Recover the last backup = %s" %(prod_flag))

def get_backup_list(count=10,env="Unknown"):
  ret=[]
  alist= util.list_s3_keys(bucket=destBucket,prefix=destPrefix)
  for ename in sorted(alist,reverse=True):
    eenv=ename.split()[3].strip()
    if eenv == env or env == '*':
      ret.append(ename)
      count=count-1
      if count == 0:
        break
  return ret

# show the last 10 most recent backups
if list_flag:
  log.debug("Listing first 10 in the bucket")
  alist= util.list_s3_keys(bucket=destBucket,prefix=destPrefix)
  print("\nRecovery Archive Name              Backup Time                Environment")
  print("---------------------------------  -------------------------  -----------")
  lcount=10
  for oname in sorted(alist,reverse=True):
    print(oname)
    lcount=lcount-1
    if lcount == 0:
      break
  print("\n")
  sys.exit(0)

if prod_flag:
  log.debug("Recovering the last %s backup" %(iEnv))
  log.debug("You are going to recover the latest %s backup" %(iEnv))
  bFileInfo= get_backup_list(count=1,env=iEnv.upper())
  print("Recovering backup taken on %s at %s" %(bFileInfo[0].split()[1].strip(),bFileInfo[0].split()[2].strip()))
  if not yes_flag:
    reply = str(input('Is this ok? any answer except yes will abort the script (yes): ')).lower().strip()
    if reply != 'yes':
      log.error("Aborting")
      sys.exit(1)
  archive_name= bFileInfo[0].split()[0].strip()

Prefix=destPrefix + '/' + archive_name
log.info("Starting %s recovery using %s archive" %(appName,archive_name))

if util.run_local_cmd_from_s3(cmd=recoverCmd,desc=appName,bucket=destBucket,objKey=Prefix):
  log.info("Recovery was successful")
else:
  log.critical("Recovery of %s failed using %s archive" %(appName,archive_name))
  sys.exit(1)
  
log.info("Recovery has completed for %s" %(archive_name))

