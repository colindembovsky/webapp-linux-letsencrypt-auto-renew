#!/bin/bash

# settings
RG="my-resource-group-name" # name of web app resource group
SKU="B2" # sku for Azure Web App plan
REGION="westus2" # region/location for web app
PLAN_NAME="my-app-plan" # name of the Web App plan
WEB_APP_NAME="my-app" # name of Web App (my-app.azurewebsites.net)
CDN="myapp.com" # CDN of custom domain, configured to poin to my-app.azurewebsites.net
WWW="1" # Set to 1 if you want to register www.my-app.com, 0 otherwise
EMAIL="me@home.com" # email address for LetsEncrypt
STAGING="1" # set to 0 for production cert, 1 for staging cert

# container registry: if you are using ACR, then all you need to set is ACR_NAME
# otherwise, set registryUrl, registryUsername and registryPassword accordingly and comment out acrPassword lines below
ACR_NAME="myregistry" # name of ACR container registry containing images - not required if you have a different registry
registryUrl="https://$ACR_NAME.azurecr.io" # customize if not using ACR
registryUser="$ACR_NAME" # customize if not using ACR
registryPassword="hard-coded-password"

###############################################################################
# these commands are idempotent, so perform no-ops if resources exist already #
###############################################################################
echo "Creating resource group $RG in REGION $REGION"
az group create -n $RG -l $REGION

echo "Create container registry"
az acr create -g $RG -n $ACR_NAME --sku Basic --admin-enabled true
echo "NOTE! Remember to push your images to this registry!"

echo "Creating app service plan $PLAN_NAME with sku $SKU"
az appservice plan create -g $RG -n $PLAN_NAME --sku $SKU --is-linux

# if you are not using ACR, set the acrPassword value manually above and comment the following 2 lines out
echo "Looking up ACR credentials"
acrPassword=$(az acr credential show -g $RG -n $ACR_NAME --query "[passwords[?name=='password'].value]" --output tsv)
registryPassword=$acrPassword

echo "Creating webapp $WEB_APP_NAME with nginx image"
az webapp create -g $RG -n $WEB_APP_NAME -p $PLAN_NAME \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "/path/to/compose.yml"  # path to the compose yml file

# can't set registry settings in create action
echo "Setting registry for $WEB_APP_NAME"
az webapp config container set -g $RG -n $WEB_APP_NAME \
    --docker-registry-server-url $registryUrl \
    --docker-registry-server-user $registryUsername \
    --docker-registry-server-password $registryPassword \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "/path/to/compose.yml"  # path to the compose yml file

echo "Enabling docker container logging"
az webapp log config -g $RG -n $WEB_APP_NAME \
    --application-logging true \
    --detailed-error-messages true \
    --web-server-logging filesystem \
    --docker-container-logging filesystem \
    --level verbose

echo "Set custom DNS $CDN for $WEB_APP_NAME"
az webapp config hostname add --webapp-name $WEB_APP_NAME -g $RG --hostname $CDN

if [ "$WWW" == "1" ]; then
    echo "Set custom DNS $CDN for $WEB_APP_NAME"
    az webapp config hostname add --webapp-name $WEB_APP_NAME -g $RG --hostname www.$CDN
fi

echo "Configure app settings"
az webapp config appsettings set -g $RG -n $WEB_APP_NAME --settings \
    url=https://$CDN \
    CDN=$CDN \
    WWW=$WWW \
    EMAIL=$EMAIL \
    STAGING=$STAGING \
    AZ_CLIENT_ID=$AZ_CLIENT_ID \
    AZ_CLIENT_KEY=$AZ_CLIENT_KEY \
    AZ_TENANT_ID=$AZ_TENANT_ID \
    PFX_PASSWORD=$PFX_PASSWORD \
    WEB_APP_NAME=$WEB_APP_NAME \
    RESOURCE_GROUP=$RG \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true

echo "Hit $WEB_APP_NAME.azurewebsites.net to start site"
curl https://$WEB_APP_NAME.azurewebsites.net