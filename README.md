# Azure Webapp for Linux LetsEncrypt Auto Renew

> Note: At present, I have tested the certificate registration, but not yet the renewal. Use at your own risk!

## Problem Statement
It is critical to secure web applications - and [LetsEncrypt](https://letsencrypt.org/) offers free certificates. However, these certificates have a 90 day expiration date, meaning you have to renew them every 90 days.

For Azure Web Apps (Windows) there is an [extension](https://github.com/sjkp/letsencrypt-siteextension) you can install to automatically register and renew the certificate. However, this extension cannot be installed on _Linux_ Azure Web Apps.

## Solution
To solve this, we need a mechanism to:

1. Request a certificate for a Linux Web App
1. Respond to the LetsEncrypt challenge so that the registration succeeds
1. Register the certificate with the Web App
1. Renew the certificate and re-register the renewed cert with the Web App

There is already a Docker image that can register and renew certs: [CertBot](https://github.com/certbot-docker/certbot-docker). However, CertBot knows nothing about Azure Web Apps.

This repo adds a custom `run.sh` script to the CertBot image to request a certificate. When the certificate is obtained, the `deploy-cert-az-webapp.sh` is executed to register the certificate with the Azure Web App. The `run.sh` script then does an infinite loop, waking every 12 hours to call `certbot renew`. If the certificate is not due for renewal, this results in a no-op. If the certificate requires renewal, renal is performed and then a post-renewal action is invoked - simply calling the `deploy-cert-az-webapp.sh` to re-register the new cert.

## Prerequisites
In order for this to work, you need to run a [multi-container](https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-multi-container-app) Linux Web App. But running your app container and certbot are not enough: you need a mechanism of routing the certbot challenge to the certbot image, and everything else to your app. We can use [nginx](https://hub.docker.com/_/nginx) for that. I have included a sample `nginx.conf` file for reference.

You also need:
1. A CDN like `mysite.com` that you own
1. DNS records, pointing your CDN to `<app>.azurewebsites.net`, following this [guide](https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-domain).
1. Persistent storage - the `run.sh` script checks to see if a cert exists, and makes a register call if it does not. This means that if you do not persist the cert, the container will attempt a register every time it starts. You could end up hitting LetsEncrypt request limits. Adding persistent storage prevents this.
1. Web App Custom DNS, pointing to the CDN you want to register the cert for.
1. An SPN that has permissions to update the web app for registering the cert: you'll need the `tenantId`, the `clientId` and `clientKey` for the SPN

## Steps
1. Create an Azure Web App
1. Register your custom DNS
1. Create a Docker image from the Dockerfile in this repo - this is the `certbot` image
1. Create a Docker image for nginx, updating the server section as show in the `nginx.conf` file in this repo - this is the `nginx` image
1. Create a Docker image for your app - this is the `app` image
1. Create a Compose yml file (use `sample-multi-container-app.yml` as a reference) updating your registry and image names as well as the app port
1. Update the following appSettings for the Web App:

Setting Name|Description|Example
---|---|---
CDN|Custom domain|`mysite.com`
WWW|Set to 0 for just the "naked" domain, set to 1 if you want to register www.CDN|`0 or 1` 
STAGING|Set to 0 for a "real" cert, set to 1 for a staging cert (for testing)|`0 or 1` 
EMAIL|Email address for registering cert - LetsEncrypt emails this address for alerts like renewals|`me@home.com`
AZ_CLIENT_ID|Azure SPN client ID|`{guid}`
AZ_CLIENT_KEY|Azure SPN client ID|`{password}`
AZ_TENANT_ID|Azure Tenant|`{guid}`
PFX_PASSWORD|A password used when converting cert to PFX, required to register with Azure Web App|`{another_password}`
WEB_APP_NAME|Name of the web app in Azure (excluding `.azurewebsites.net`)|`my-web-app`
RESOURCE_GROUP|Name of the Resource Group the Web App is in|`my-rg`
DEBUG|Set to 0 for running script, set to 1 for debuggin (dry run)|`0 or 1`

## Gotchas
- I could not get this to work if my app used port 80 or 8080 - your app **must** expose some other port.
- Certbot only responds to traffic when it issues the certificate request. After that, it does not respond, so your nginx logs will say "Unable to contact upstream certbot". This can be safely ignored.
- Make sure your DNS points to the Azure Web App before configuring the compose configuration, otherwise certificate challenge will fail.
- You should enable container logging to see what's going on in the containers in the web app.
- You must actually _hit_ the site to update the container settings if you add/update them - otherwise the web app does not seem to spin up the containers.

## Sample Script
The `sample-web-app-creation.sh` script automates all the tasks above, assuming you have container images and DNS configured and that you're using Azure Container Registry - otherwise replace container registry URL, user and password to your registry.