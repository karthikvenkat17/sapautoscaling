#!/bin/bash
#Author : Karthik Venkatraman
set -x

## Error handling ###

trap 'catch' ERR
catch() {
  echo "An error has occurred. App server not stopped"
  exit 1
}


## Variables section ###
SID="$1"
sid=$(echo $SID | tr '[:upper:]' '[:lower:]')
sidadm=${sid}adm
instancenr="$2"
apphostname="$3"
APPHOSTNAME=$(echo $apphostname | tr '[:lower:]' '[:upper:]')
timeout="$4"


if [[ -z "$SID" || -z "$apphostname" || -z "$instancenr" || -z "$timeout"  ]]; then
echo "Run the script with SID, instance number and hostname eg. app_decom.sh TST 00 tst-app-avm-1 timeout"
exit
fi

if [ "$(whoami)" != "root" ];then
echo "Run the script as root user"
exit
fi

##Main program##
##Setting up home directory##

##Creating new profile

echo "Stopping SAP app server"
su - $sidadm -c "/usr/sap/${SID}/exe/run/sapcontrol -nr $instancenr -function Stop $timeout"

if [ $? == 0 ];then
echo "SAP stopped successfully"
else
echo "SAP could not be stopped. Check logs"
exit 1
fi