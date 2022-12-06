log_level= 4
log_level_info_count= 0

def set_level(level):
  global log_level
  
  if level == 'ERROR':
    log_level= 0
  elif level == 'WARN': 
    log_level= 1
  elif level == 'INFO':
    log_level= 2
  elif level == 'DEBUG':
    log_level= 3
  else: 
    write(level=1,message="Invalid token used for set_level - log level unchanged")

def write(level,message,abort_it=False):
  import sys
  global log_level_info_count
  global log_level

  if log_level == 4 and log_level_info_count == 0:
    print ("%s: %s" %("INFO","Logging is set to DEBUG by default"))
    print ("%s: %s" %("INFO","To override use the logger set_level(\"LEVEL\") function to change"))
    print ("%s: %s" %("INFO", "Options are: DEBUG / INFO / WARN / ERROR"))
    log_level_info_count += 1
    log_level= 3

  if level <= log_level:
    if level == 0:
      mPrefix= 'ERROR'
    if level == 1: 
      mPrefix= 'WARN'
    if level == 2:
      mPrefix= 'INFO'
    if level == 3: 
      mPrefix= 'DEBUG'

    print ("%s: %s" %(mPrefix,message))

  if abort_it:
    print ("ERROR: Exiting Now")
    sys.exit(1)
