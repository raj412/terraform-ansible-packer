import logging as log
import boto3
from botocore.exceptions import ClientError
import base64
import sys


def get_region():
  log.debug("Starting get_region")
  my_session= boto3.session.Session()
  my_region=  my_session.region_name
  return my_region

def get_secret(secret_name,region_name=None):
  log.debug("Starting get_secret")
  if region_name == None:
    try:
      region_name= get_region()
    except:
      log.error("No valid region found")
      sys.exit(1)
  log.debug("region_name = %s" %(region_name))
  # Create a Secrets Manager client
  session = boto3.session.Session()
  client = session.client(
    service_name='secretsmanager',
    region_name=region_name
  )
  try:
    get_secret_value_response = client.get_secret_value(
      SecretId=secret_name
    )
  except ClientError as e:
    if e.response['Error']['Code'] == 'DecryptionFailureException':
      # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InternalServiceErrorException':
      # An error occurred on the server side.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InvalidParameterException':
      # You provided an invalid value for a parameter.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InvalidRequestException':
      # You provided a parameter value that is not valid for the current state of the resource.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'ResourceNotFoundException':
      # We can't find the resource that you asked for.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
  else:
    # Decrypts secret using the associated KMS CMK.
    # Depending on whether the secret is a string or binary, one of these fields will be populated.
    if 'SecretString' in get_secret_value_response:
      secret = get_secret_value_response['SecretString']
      return secret
    else:
      decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
      return decoded_binary_secret


def create_secret(secret_name,secret_type=None,secret_value=None,region_name=None):
  log.debug("Starting get_secret")
  if region_name == None:
    try:
      region_name= get_region()
    except:
      log.error("No valid region found")
      sys.exit(1)
  log.debug("region_name = %s" %(region_name))
  # Create a Secrets Manager client
  if secret_type == None:
    secret_type == 'string'

  if not secret_type == 'string' and not secret_type == 'binary':
    log.critical("secret_type %s is invalid - must be 'string' or 'binary'" %(secret_type))
    sys.exit(1)

  session = boto3.session.Session()
  client = session.client(
    service_name='secretsmanager',
    region_name=region_name
  )

  try:

    if secret_type == 'string':
      create_secret_value_response = client.create_secret(
        Name=secret_name,
        SecretString=secret_value,
      )
    else:
      create_secret_value_response = client.create_secret(
        Name=secret_name,
        SecretBinary=secret_value
      )

  except ClientError as e:
    if e.response['Error']['Code'] == 'ResourceExistsException':
      raise e

    elif e.response['Error']['Code'] == 'LimitExceededException':
      raise e
    
    elif e.response['Error']['Code'] == 'MalformedPolicyDocumentException':
      raise e

    elif e.response['Error']['Code'] == 'PreconditionNotMetException':
      raise e

    elif e.response['Error']['Code'] == 'EncryptionFailureException':
      raise e

    elif e.response['Error']['Code'] == 'InternalServiceErrorException':
      raise e

    elif e.response['Error']['Code'] == 'InvalidParameterException':
      # You provided an invalid value for a parameter.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'InvalidRequestException':
      # You provided a parameter value that is not valid for the current state of the resource.
      # Deal with the exception here, and/or rethrow at your discretion.
      raise e
    elif e.response['Error']['Code'] == 'ResourceNotFoundException':
      raise e
  
  print(create_secret_value_response)
  


  return True

