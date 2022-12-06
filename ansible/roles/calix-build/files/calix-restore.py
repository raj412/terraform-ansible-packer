#!/usr/bin/env python3

import lutils as util
import logger as log
import argparse
import sys
import os
import lsecrets as sec
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
import json

log.set_level('INFO')

appName= "Calix"
destBucket= 'litfibre-infra'
destPrefix= 'calix-backup-archive'
backupPrefix='/opt/PMAPMAA/backup'
recoverCmd= '/opt/PMAPMAA/bin/activate-db-restore.sh '


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
setArgs.add_argument('-d','--dev',action='store_true',
                     help='Optional - Recover for the Dev enviornment')

args= setArgs.parse_args()
list_flag= args.list
archive_name=args.archive_name
prod_flag= args.recover
yes_flag= args.yes
dev_flag= args.dev


# Validate command line options

# List option selected 
if ((list_flag == True) and ((archive_name != None) or (prod_flag == True))):
  log.write(level=0,message="The list archive option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# Recover option selected 
if((prod_flag == True) and ((archive_name != None) or (list_flag == True))):
  log.write(level=0, message="The recover option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# file option selected
if((archive_name != None) and ((prod_flag == True) or (list_flag == True))):
  log.write(level=0, message="The file option is an exclusive option")
  setArgs.print_help()
  sys.exit(1)

# No options selected
if ((list_flag == False) and (archive_name == None) and (prod_flag == False)):
  setArgs.print_help()
  sys.exit(1)

log.write(level=3,message="list backup files = %s" %(list_flag))
log.write(level=3,message="Archive name = %s" %(archive_name))
log.write(level=3,message= "Recover the last backup = %s" %(prod_flag))

def do_dev():
  authuser= json.loads(sec.get_secret('dev/calix/security'))['username']
  authpass= json.loads(sec.get_secret('dev/calix/security'))['password']
  accuser=  json.loads(sec.get_secret('dev/calix/dev-admin'))['username']
  accpass=  json.loads(sec.get_secret('dev/calix/dev-admin'))['password']
  url= "https://127.0.0.1:3443/rest/v1/security/user"
  headers= {
            'Content-Type': 'application/json',
            'authpassword': authpass,
            'authuser': authuser
           }
  data= "{\"userName\" : \"" + accuser + "\", \"password\" : \"" + accpass + "\",\"roles\": [{\"name\": \"Administrator\"}]}"
  rtn= requests.post(url,data=data,headers=headers, verify=False)
  if rtn.status_code == 200:
    log.write(level=2,message="%s user created successfully" %(accuser))
  elif rtn.status_code == 403:
    log.write(level=2,message="%s user already exists" %(accuser))
  else:
    log.write(abort_it=True,level=0,message="%s user creation FAILED with status code %s - %s" %(accuser,rtn.status_code,rtn.content)) 
  url= "https://127.0.0.1:3443/rest/v1/security/user/" + accuser
  data= "{\"userName\" : \"" + accuser + "\", \"password\" : \"" + accpass + "\", \"userGroup\":\"DEFAULTUSERGROUP\", \"roles\": [{\"name\": \"Administrator\"}]}"
  rtn= requests.put(url,data=data,headers=headers, verify=False)
  if rtn.status_code == 200:
    log.write(level=2,message="%s user updated successfully" %(accuser))
  else:
    log.write(abort_it=True,level=0,message="%s user update FAILED with status code %s - %s" %(accuser,rtn.status_code,rtn.content))

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
  log.write(level=3,message="Listing first 10 in the bucket")
  bList= get_backup_list(count=10, env='*')
  print("\nRecovery Archive Name   Backup Time                Environment")
  print("----------------------  -------------------------  -----------")
  for oname in bList:
    print(oname)
  print("\n")
  sys.exit(0)

if prod_flag:
  log.write(level=3, message="Recovering the last production backup")
  log.write(level=1, message="You are going to recover the latest production backup")
  bFileInfo= get_backup_list(count=1,env="PROD")
  print("Recovering backup taken on %s at %s" %(bFileInfo[0].split()[1].strip(),bFileInfo[0].split()[2].strip()))
  if not yes_flag:
    reply = str(input('Is this ok? any answer except yes will abort the script (yes): ')).lower().strip()
    if reply != 'yes':
      log.write(abort_it=True,level=0,message="Aborting")
  archive_name= bFileInfo[0].split()[0].strip()
  log.write(level=2,message="Restarting Calix")
  if(util.run_local_cmd(cmd="systemctl restart pmapmaad",desc="Latest Calix archive recovery")):
    log.write(level=2,message="Calix restart was successful")
  else:
    log.write(abort_it=True,level=0,message="Calix restart FAILED")

# Copy backup file from S3 to the /opt/PMAAMAA/backup directory
log.write(level=2,message="Starting copy for %s archive from S3 %s/%s" %(archive_name,backupPrefix,archive_name))
util.copy_s3_to_file(bucket=destBucket,objKey=destPrefix + '/' + archive_name,filepath=backupPrefix + '/' + archive_name)
log.write(level=2,message="S3 copy has completed")
# Run the activate restore command - /opt/PMAAMAA/bin/activate-db-restore.sh
log.write(level=2,message="Starting %s recovery using %s archive" %(appName,archive_name))

recoverCmd= "/opt/PMAPMAA/bin/activate-db-restore.sh " + archive_name + " 1>/dev/null 2>&1"
util.run_local_cmd(cmd=recoverCmd, desc="Calix Recovery")
if dev_flag:
  do_dev()

log.write(level=2,message="Recovery has completed for %s" %(archive_name))
