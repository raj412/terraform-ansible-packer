#!/usr/bin/env python3
import os
import json
import lutils as util
import lsecrets as sec
import logger as log
import boto3
from botocore.exceptions import ClientError

log.set_level('ERROR')
mongopf='/etc/default/telegraf'

ienv=util.get_tag_value("Environment").lower()
if (not os.path.isfile(mongopf)) or (os.path.getsize(mongopf) == 0):
  mongo_username= json.loads(sec.get_secret(ienv + '/calix/activate'))['username']
  mongo_password= json.loads(sec.get_secret(ienv + '/calix/activate'))['password']
  elastic_username= json.loads(sec.get_secret(ienv + '/calix/elastic'))['username']
  elastic_password= json.loads(sec.get_secret(ienv + '/calix/elastic'))['password']
  with open(mongopf,'w') as wfile:
    wfile.write('mongo_username='   + mongo_username + '\n' 
              + 'mongo_password='   + mongo_password + '\n'
              + 'elastic_username=' + elastic_username + '\n' 
              + 'elastic_password=' + elastic_password + '\n')
  os.chmod(mongopf, 0o700)
  util.run_local_cmd('systemctl restart telegraf')

json_out={}
if os.system('/opt/PMAPMAA/bin/processList.sh 1>/dev/null 2>&1'):
  json_out.update({'status': 0})
else:
  json_out.update({'status': 1})
print(json.dumps(json_out))