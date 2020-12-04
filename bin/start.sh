#!/bin/bash

set -xe

if ! [ -z "${AUTH_FQDN}" ]; then
  sed -i "s;'entityID' => .*;'entityID' => 'https://${AUTH_FQDN}/shibboleth-sp',;" \
      /var/www/simplesamlphp/config/authsources.php
  sed -i "s,var wayf_sp_handlerURL = .*,var wayf_sp_handlerURL = \"https://${AUTH_FQDN}/simplesaml/module.php/saml/sp/discoresp.php\";," \
      /var/www/simplesamlphp/templates/selectidp-dropdown.php
fi
if ! [ -z "${CG_FQDN}" ]; then
  sed -i "s;'entityId' => .*;'entityId' => 'https://${CG_FQDN}/idp/shibboleth',;" \
      /var/www/simplesamlphp/config/config.php
fi
if ! [ -z "${DS_FQDN}" ]; then
  sed -i "s,var embedded_wayf_URL = .*,var embedded_wayf_URL = \"https://${DS_FQDN}/WAYF/embedded-wayf.js\";," \
      /var/www/simplesamlphp/templates/selectidp-dropdown.php
  sed -i "s,var wayf_URL = .*,var wayf_URL = \"https://${DS_FQDN}/WAYF\";," \
      /var/www/simplesamlphp/templates/selectidp-dropdown.php
fi

# Setup the keys for nginx
cp -p $CERT_DIR/idp-proxy.chained.cer /etc/pki/nginx/
cp -p $CERT_DIR/idp-proxy.key /etc/pki/nginx/private/

# Setup the keys for simplesamlphp
cp -p $CERT_DIR/idp-proxy.cer /var/www/simplesamlphp/cert/
cp -p $CERT_DIR/idp-proxy.key /var/www/simplesamlphp/cert/
cp -p $CERT_DIR/gakunin-signer.cer /var/www/simplesamlphp/cert/

# Set cron job to update metadata
echo "@reboot /usr/bin/sleep 10 && /usr/bin/curl --silent --insecure \"https://localhost/simplesaml/module.php/cron/cron.php?key=$CRON_SECRET&tag=daily\" > /dev/null 2>&1" > /var/spool/cron/root
echo "0 0 * * * /usr/bin/curl --silent --insecure \"https://localhost/simplesaml/module.php/cron/cron.php?key=$CRON_SECRET&tag=daily\" > /dev/null 2>&1" >> /var/spool/cron/root

# Setup simplesamlphp config module
cat << EOS > /var/www/simplesamlphp/config/module_cron.php
<?php
/*
 * Configuration for the Cron module.
 */

\$config = array (

        'key' => '${CRON_SECRET}',
        'allowed_tags' => array('daily', 'hourly', 'frequent'),
        'debug_message' => TRUE,
        'sendemail' => FALSE,

);
EOS


/usr/bin/supervisord -n -c /etc/supervisord.conf
