import json
import subprocess
import logging as log
import boto3
import io
import signal
import sys
from ec2_metadata import ec2_metadata

def get_tag_value(tagName):

  iRegion= ec2_metadata.region
  iInstanceId= ec2_metadata.instance_id
  client = boto3.client('ec2')
  response = client.describe_tags(
    Filters=[
      {
        'Name'   : 'resource-id',
        'Values' : [iInstanceId ]
      },
      {
        'Name'   : 'resource-type',
        'Values' : ['instance']
      },
      {
        'Name'   : 'key',
        'Values' : [tagName]
      }
    ],
    MaxResults=123,
    NextToken='get_next_tag_value'
  )
  try:
    response['Tags'][0]['Value']
  except:
    log.critical("get_tag_value for %s failed" %(tagName))
    sys.exit(1)
  return response['Tags'][0]['Value']


def list_s3_keys(bucket=None,prefix=None):
  s3c = boto3.client('s3')
  s3= boto3.resource('s3')
  returnList= []
  rbucket = s3.Bucket(bucket)
  for obj in rbucket.objects.filter(Delimiter='/', Prefix=prefix + '/'):
    modDate= obj.last_modified
    objEntry= obj.key.split('/')
    if objEntry[-1] == "":
      continue
    objTags = s3c.get_object_tagging(Bucket=bucket,Key=obj.key)
    objEnv="Unknown"
    if json.dumps(objTags['TagSet']) != "[]":
      for tagEntry in objTags['TagSet']:
        if tagEntry['Key'] == 'Env':
          objEnv = tagEntry['Value']

    objList=objEntry[-1] + "  " + str(modDate) + "  " + objEnv
    returnList.append(objList)
  return returnList

def run_local_cmd(cmd=None,lang=None,desc=None,environment="Windows"):
  if lang == 'powershell':
    cmd = ['powershell.exe',cmd]
  elif lang == 'python':
    cmd = ['python', cmd]
  else:
    cmd = [cmd]
  log.debug("command is %s" % (json.dumps(cmd, indent=4)))
  try:
    run_cmd= subprocess.run(cmd, check=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True, shell=True)
  except subprocess.CalledProcessError as e:
    log.error("Command failed - return code = %s" %(e.returncode))
    log.error("Command output = %s" %(e.stdout))
    log.error("Command error output = %s" %(e.stderr))
    return False
  log.info("%s" %(run_cmd.stdout))
  return True          



def run_local_cmd_to_s3(cmd=None,desc=None,bucket=None,dest=None,environment="Unknown"):
  cmd = [cmd]
  log.debug("command is %s" % (json.dumps(cmd)))
  run_cmd= subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=False, shell=True)
  return_code = run_cmd.returncode
  if return_code != 0:
    log.critcal("Return code from the %s command was %s - Error: %s" % (cmd,return_code,run_cmd.stderr.strip()))
    return False
  s3 = boto3.resource('s3')
  object = s3.Object(bucket, dest)
  object.put(Body=run_cmd.stdout)
  #Tag it
  s3_client = boto3.client('s3')
  try:
    put_tags_response = s3_client.put_object_tagging(Bucket=bucket,Key=dest,
          Tagging={
            'TagSet': [{'Key': 'Env','Value': environment}]})
  except:
    log.error("S3 tagging failed")
    return False
  return True

def run_local_cmd_from_s3(cmd=None,desc=None,bucket=None,objKey=None):
  cmd = [cmd]
  log.debug("command = %s - bucket = %s - objKey = %s " %(json.dumps(cmd),bucket,objKey))
  s3 = boto3.resource('s3')
  obj = s3.Object(bucket, objKey)
  body = obj.get()['Body'].read()
  # Lol wtf - Imakes the stream run with out an error
  signal.signal(signal.SIGCHLD, signal.SIG_IGN)
  recoveryStream = io.BytesIO(body)
  run_cmd= subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=False, shell=True)
  run_cmd.stdin.write(body)
  output = run_cmd.communicate()[0]
  return_code = run_cmd.returncode
  if return_code != 0:
    log.critical("Return code from the %s command was %s - Error: %s" % (cmd,return_code,run_cmd.stderr))
    sys.exit(1)
  output = run_cmd.stdout
  return True

def copy_s3_to_file(bucket=None,objKey=None,filepath=None):
  s3 = boto3.client('s3')
  with open(filepath, 'wb') as data:
    s3.download_fileobj(bucket, objKey, data)


def copy_file_to_s3(bucket=None,object_name=None,filename=None,environment="Unknown"):
  import os
  import boto3
  from botocore.exceptions import ClientError

  if object_name is None:
    object_name = os.path.basename(filename)
    
  s3_client = boto3.client('s3')
  try:
    response = s3_client.upload_file(filename, bucket, object_name)
  except ClientError as e:
    log.error(e)
    return False
  try:
    response = s3_client.put_object_tagging(Bucket=bucket,
      Key=object_name,
      Tagging={'TagSet': [{'Key': 'Env','Value': environment}]})
    if response['ResponseMetadata']['HTTPStatusCode'] == "200":
      return True
  except ClientError as e:
    log.error("S3 tagging failed")
    log.error(e)
    return False
  return True
