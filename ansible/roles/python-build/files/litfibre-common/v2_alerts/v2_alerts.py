#!/usr/bin/env python3
#####################################################################
#  This library creates/deletes an alert file                       #
#  An alert file is the trigger for the send-alert-poller.py        #
#  to send and alert to prometheus alertmanager and onto Pager duty #
#####################################################################

import logging as log
import glob
import os
import json
from datetime import datetime

#Default Path
alertPath= "/opt/management/alerts/"

#Function to create an alert file
def create_alert(alertname,description,summary,message,alert_level="warning"):
    log.debug("Starting create_alert")

    alertFile= alertPath + alertname + ".alt"
    log.debug("Alert file = %s" %(alertFile))
    # check to see if there is an alert file already
    fileList= glob.glob(alertFile)
    for fileName in fileList:
        found_alert_name= fileName.split('.')[0]
        if found_alert_name == alertname:
            delete_alert(alertname)
    # create dict to write to the file
    processid= os.getpid()
    alerttime= datetime.utcnow().isoformat("T") + "Z"
    alertDict= {'alerttime': alerttime,'processid': processid,'alertname': alertname,'description': description, 'summary': summary, 'message': message,'severity': alert_level}
    alertJson= json.dumps(alertDict)
    with open(alertFile,"w+") as af:
        af.write(alertJson)
    log.debug("Alert File %s was written" %(alertFile))

def delete_alert(alertname):
    log.debug("Starting delete_alert")
    alertFile= alertPath + alertname + ".alt"
    log.debug("Alert file = %s" %(alertFile))
    # check to see if there is an alert file already
    fileList= glob.glob(alertFile)
    if len(fileList) != 0:
        log.debug("removing Alert file")
        os.remove(alertFile)