#!/bin/bash
#Author : Karthik Venkatraman
set -x

## Error handling ###

trap 'catch' ERR
catch() {
  echo "An error has occurred. App server not installed"
  exit 1
}


## Variables section ###
SID="$1"
sid=$(echo $SID | tr '[:upper:]' '[:lower:]')
sidadm=${sid}adm

orighostname="$2"
ORIGHOSTNAME=$(echo $orighostname | tr '[:lower:]' '[:upper:]')
newhostname="$3"
NEWHOSTNAME=$(echo $newhostname | tr '[:lower:]' '[:upper:]')

if [[ -z "$SID" || -z "$orighostname" || -z "$newhostname" ]]; then
echo "Run the script with SID, original hostname and new hostname parameters eg. app_install.sh SBX tst-app-avm-1 tst-app-avm-2"
exit
fi

if [ "$(whoami)" != "root" ];then
echo "Run the script as root user"
exit
fi

##Main program##
##Setting up home directory##
echo "Backing up the home directory"
homedir=$(echo ~tstadm)
cp -pr $homedir $homedir.old

echo "Replacing host name in the home directory"
cd $homedir

mv .sapenv_${orighostname}.sh .sapenv_${newhostname}.sh
mv .sapenv_${orighostname}.csh .sapenv_${newhostname}.csh
mv .sapsrc_${orighostname}.sh .sapsrc_${newhostname}.sh
mv .sapsrc_${orighostname}.csh .sapsrc_${newhostname}.csh
mv .dbenv_${orighostname}.sh .dbenv_${newhostname}.sh
mv .dbenv_${orighostname}.csh .dbenv_${newhostname}.csh
mv .dbsrc_${orighostname}.sh .dbsrc_${newhostname}.sh
mv .dbsrc_${orighostname}.csh .dbsrc_${newhostname}.csh

##Renaming sapservices file##
cp -pr /usr/sap/sapservices /usr/sap/sapservices.old
sed -i 's/'$orighostname'/'$newhostname'/g' /usr/sap/sapservices

##Creating new profile
cp -pr /sapmnt/$SID/profile/${SID}_D00_${orighostname} /sapmnt/${SID}/profile/${SID}_D00_${newhostname}
sed -i 's/'$orighostname'/'$newhostname'/g' /sapmnt/${SID}/profile/${SID}_D00_${newhostname}
sed -i 's/'$ORIGHOSTNAME'/'$NEWHOSTNAME'/g' /sapmnt/${SID}/profile/${SID}_D00_${newhostname}

##Starting SAP

echo "Starting SAP app server"
su - $sidadm -c "/usr/sap/${SID}/D00/exe/sapcontrol -nr 00 -function StartService ${SID}"
sleep 5
su - $sidadm -c "/usr/sap/${SID}/D00/exe/sapcontrol -nr 00 -function Start"
flag=0
retry=0
until [ "$retry" -ge 10 ]
do
    pcount=$(ps -ef | grep -i dw | wc -l)
    if [ "$pcount" -gt 20 ];then
        flag=1
        break
    else
        echo "Waiting for SAP to to be available"
        sleep 5
    fi
retry=$(($retry+1))
done

if [ $flag == 1 ];then
echo "SAP started successfully"
else
echo "SAP could not be started. Check logs"
exit 1
fi