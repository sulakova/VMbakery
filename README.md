# Scripts which creates "bakery" for VM images

You can test these commands and script `./backery/backery.sh` from this repo.
First of all please clone this repository `git clone https://github.com/valda-z/azure-vm-image-bakery.git` and then you can run this example commands from directory `azure-vm-image-bakery`.

How it works?
* First step - create resource group for images and blobstorage for communication between bakery and VM in creation process.
* Second step is bakery.sh - script which creates temporary resource group, VM is created in this group, application are installed to VM and finally VM is generalized. Image of this pre-baked VM is stored like custom image. For this demo is used tomcat server with one WAR sample application installed like default (root) app.
* Last step - there is sample which creates VM scale set from final baked image and we can test that application works there.

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

#---------------------------------------------------------------------
# now lets run part of CI/CD pipeline - run bakery and create image ..
./bakery/backery.sh --location $LOCATION --resource-group-backery $RG --imagename $IMAGENAME --bakery-storage $BAKERYSTORAGE
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# now lets create test VMSS cluster
myimg=$(az image show -g ${RG} -n ${IMAGENAME} --query "id" -otsv)
RESOURCE_GROUP="QTEST2"
az group create -l ${LOCATION} -n ${RESOURCE_GROUP}

# Create VMSS
az vmss create -n vmss \
  --resource-group ${RESOURCE_GROUP} \
  --location ${LOCATION} \
  --instance-count 5 \
  --vm-sku Standard_D1_v2 \
  --image "${myimg}"

# Create Load Balancer probe
az network lb probe create \
  --resource-group ${RESOURCE_GROUP} \
  --name vmssLBProbe \
  --lb-name vmssLB \
  --protocol http --port 8080 --path /

# Create Load Balancer rule
az network lb rule create \
  --resource-group ${RESOURCE_GROUP} \
  --name vmssLBRule \
  --lb-name vmssLB \
  --backend-pool-name vmssLBBEPool \
  --backend-port 8080 \
  --frontend-ip-name loadBalancerFrontEnd \
  --frontend-port 80 \
  --protocol tcp \
  --probe-name vmssLBProbe

# And now we cann connect to ...
pubip=$(az network public-ip show --resource-group ${RESOURCE_GROUP} --name vmssLBPublicIP --query "ipAddress" -otsv)
echo "Connect to service: http://${pubip}"
#---------------------------------------------------------------------

```
