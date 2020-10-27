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
instancenr="$2"
orighostname="$3"
ORIGHOSTNAME=$(echo $orighostname | tr '[:lower:]' '[:upper:]')
newhostname="$4"
NEWHOSTNAME=$(echo $newhostname | tr '[:lower:]' '[:upper:]')

if [[ -z "$SID" || -z "$orighostname" || -z "$newhostname"  || -z "$instancenr" ]]; then
echo "Run the script with SID, instance numberm, original hostname and new hostname parameters eg. app_install.sh SBX 00 tst-app-avm-1 tst-app-avm-2"
exit 1
fi

if [ "$(whoami)" != "root" ];then
echo "Run the script as root user"
exit 1
fi

##Main program##
##Setting up home directory##
echo "Backing up the home directory"
homedir="/home/$sidadm"
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
mv ${homedir}/.hdb/${orighostname} ${homedir}/.hdb/${newhostname}


##Renaming sapservices file##
cp -pr /usr/sap/sapservices /usr/sap/sapservices.old
sed -i 's/'$orighostname'/'$newhostname'/g' /usr/sap/sapservices

##Creating new profile
cp -pr /sapmnt/$SID/profile/${SID}_D${instancenr}_${orighostname} /sapmnt/${SID}/profile/${SID}_D${instancenr}_${newhostname}
sed -i 's/'$orighostname'/'$newhostname'/g' /sapmnt/${SID}/profile/${SID}_D${instancenr}_${newhostname}
sed -i 's/'$ORIGHOSTNAME'/'$NEWHOSTNAME'/g' /sapmnt/${SID}/profile/${SID}_D${instancenr}_${newhostname}

##Starting SAP
echo "Ensure hostname is set properly"
sleep 5
if [ "$(hostname)" != $newhostname ];then
echo "Hostname not set properly"
exit 1
fi

echo "Starting SAP app server"
su - $sidadm -c "/usr/sap/${SID}/D${instancenr}/exe/sapcontrol -nr $instancenr -function StartService ${SID}"
sleep 5
su - $sidadm -c "/usr/sap/${SID}/D${instancenr}/exe/sapcontrol -nr $instancenr -function Start"
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