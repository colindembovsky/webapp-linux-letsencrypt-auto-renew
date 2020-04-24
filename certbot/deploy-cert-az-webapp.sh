#!/bin/sh

certPath="$WORKING_PATH/live/$CDN"

if [ ! -f "$WORKING_PATH/live/$CDN/fullchain.pem" ]; then
  echo "ERROR: $WORKING_PATH/live/$CDN/fullchain.pem does not exist"
  exit 1
fi

# convert pem to pfx for azure web app
echo "Converting pem to pfx"
openssl pkcs12 \
    -password pass:$PFX_PASSWORD \
    -inkey $certPath/privkey.pem \
    -in $certPath/cert.pem \
    -export -out $certPath/cert.pfx

# upload and get the thumbprint
if [ ! -z $DEBUG ] && [ $DEBUG != "TRUE" ]; then
    echo "DEBUG:: Running pfx upload and bind cert commands here"
    echo "DEBUG:: WebApp: $WEB_APP_NAME"
    echo "DEBUG:: Resource $RESOURCE_GROUP"
    echo "Contents of $certPath"
    ls -la $certPath
    
else
    echo "Running az login"
    az login --service-principal -u $AZ_CLIENT_ID -p $AZ_CLIENT_KEY --tenant $AZ_TENANT_ID

    echo "Upload $certPath/cert.pfx to $WEB_APP_NAME in $RESOURCE_GROUP and get thumbprint"
    thumbprint=$(az webapp config ssl upload --certificate-file $certPath/cert.pfx \
                --certificate-password $PFX_PASSWORD \
                --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP \
                --query thumbprint --output tsv)
    
    # bind using the thumbprint
    echo "Bind cert"
    az webapp config ssl bind \
        --certificate-thumbprint $thumbprint \
        --ssl-type SNI \
        --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP
fi

echo "Done!"