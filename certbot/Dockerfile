FROM certbot/certbot:v1.3.0

ENV WORKING_PATH "/etc/letsencrypt"

# install az cli
RUN pip uninstall -y enum34
RUN \
  apk update && \
  apk add bash py-pip && \
  apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python-dev make && \
  pip --no-cache-dir install -U pip && \
  pip --no-cache-dir install azure-cli && \
  apk del --purge build && \
  az -v

COPY *.sh /usr/local/bin/

ENTRYPOINT ["run.sh"]

# env vars required for running:
# CDN: the domain (e.g. mysite.com)
# WWW: 0 for no www, 1 for registering www with naked domain
# STAGING: 0 for prod, 1 for staging
# EMAIL: email for registering cert

# AZ_CLIENT_ID: Azure SPN ID
# AZ_CLIENT_KEY: Azure SPN Key
# AZ_TENANT_ID: Azure Tenant id
# PFX_PASSWORD: password for cert to upload to Azure
# WEB_APP_NAME: name of web app to upload cert to
# RESOURCE_GROUP: name of resource group of web app

# DEBUG: FALSE for prod, TRUE for debugging