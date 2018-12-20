#!/bin/bash

#--------------------------------
# Parameters:
#  $1 : VM name
#  $2 : blob storage account name
#  $3 : sas token for blob storage
#--------------------------------

# install tomcat
yum install -y curl tomcat

# start tomcat
systemctl enable tomcat
systemctl restart tomcat

# install test WAR
curl https://tomcat.apache.org/tomcat-5.5-doc/appdev/sample/sample.war > /usr/share/tomcat/webapps/ROOT.war

# install finished - signal to BACKERY ..
echo "DONE" > done.txt
curl -X PUT -T ./{done.txt} -H "x-ms-date: $(date -u)" -H "x-ms-blob-type: BlockBlob" "https://${2}.blob.core.windows.net/signals/${1}.signal?${3}"

# generalize VM
waagent -deprovision+user -force

