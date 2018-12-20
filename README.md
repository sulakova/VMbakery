# azure-vm-image-bakery

```bash
export RG=QBAKERY
export RGTMP=QBAKERYTMP
export LOCATION=northeurope
export BAKERYSTORAGE=valdatest001
export VMNAME=myVM
export IMAGENAME=myAppImage-v1

#create RG for BAKERY assets
az group create -l ${LOCATION} -n ${RG}

# create storage account
az storage account create -n ${BAKERYSTORAGE} -g ${RG} -l ${LOCATION} --sku Standard_LRS --kind StorageV2
az storage container create -n signals --account-name ${BAKERYSTORAGE}



```
