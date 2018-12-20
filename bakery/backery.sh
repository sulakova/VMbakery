#!/bin/bash

# -----------------------------------------------------------
# this script can be used in CI/CD pipeline
# -----------------------------------------------------------

LOCATION=""
RG_BAKERY=""
RG_TMP=""
VMNAME=""
IMAGENAME=""
BAKERYSTORAGE=""

while [[ $# > 0 ]] 
do
  key="$1"
  shift
  case $key in
    --location)
      LOCATION="$1"
      shift
      ;;
    --resource-group-backery)
      RG_BAKERY="$1"
      shift
      ;;
    --imagename)
      IMAGENAME="$1"
      shift
      ;;
    --bakery-storage)
      BAKERYSTORAGE="$1"
      shift
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done


function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    exit -1
  fi
}

RG_TMP="${RG_BAKERY}$(od -vAn -N4 -tu4 < /dev/urandom | xargs)"
echo $RG_TMP
VMNAME="vm$(od -vAn -N4 -tu4 < /dev/urandom | xargs)"

throw_if_empty --location $LOCATION
throw_if_empty --resource-group-backery $RG_BAKERY
throw_if_empty --imagename $IMAGENAME
throw_if_empty --bakery-storage $BAKERYSTORAGE

az group create -l ${LOCATION} -n ${RG_TMP}

# create SAS token for signalizing
end=$(date -d "60 minutes" '+%Y-%m-%dT%H:%MZ')
sas=$(az storage container generate-sas -n signals --account-name  ${BAKERYSTORAGE} --https-only --permissions dlrw --expiry $end -otsv)

if [ "True" = "$(az storage blob exists -c signals --account-name  ${BAKERYSTORAGE} -n ${VMNAME}.signal -otsv)" ] ; then
  az storage blob delete -c signals --account-name  ${BAKERYSTORAGE} -n ${VMNAME}.signal
fi

# prepare cloud init file
echo "#cloud-config
package_upgrade: true
packages:
  - curl
runcmd:
  - curl -s https://raw.githubusercontent.com/valda-z/azure-vm-image-bakery/master/bakery/assets/install.sh | bash -s -- ${VMNAME} ${BAKERYSTORAGE} \"${sas}\"
" > ${RB_TMP}.txt

# create VM and install software things inside
az vm create \
    --resource-group ${RG_TMP} \
    --location ${LOCATION} \
    --name ${VMNAME} \
    --image "OpenLogic:CentOS:7-CI:latest" \
    --size Standard_DS2_v2 \
    --custom-data ${RB_TMP}.txt

# wait for VM finalize init script ...
mysig="False"
echo -n " .. waiting for install complete "
while [  "${mysig}" = "False" ]; do
    echo -n "."
    sleep 3
    mysig=$(az storage blob exists -c signals --account-name  ${BAKERYSTORAGE} -n ${VMNAME}.signal -otsv)
done
echo ""
echo " .. install done."

# prepare iamge
az vm deallocate --resource-group ${RG_TMP} --name ${VMNAME}
az vm generalize --resource-group ${RG_TMP} --name ${VMNAME}
diskid=$(az vm show --resource-group ${RG_TMP} --name ${VMNAME} --query "storageProfile.osDisk.managedDisk.id" -otsv)
az image create -g ${RG_BAKERY} -n ${IMAGENAME} --os-type Linux --source "${diskid}"

# drop TMP RG after image creation process
az group delete -n ${RG_TMP} --yes

if [ "True" = "$(az storage blob exists -c signals --account-name  ${BAKERYSTORAGE} -n ${VMNAME}.signal -otsv)" ] ; then
  az storage blob delete -c signals --account-name  ${BAKERYSTORAGE} -n ${VMNAME}.signal
fi
