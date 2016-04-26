#!/usr/bin/env bash

# initialize the letsencrypt.sh environment
setup_letsencrypt() {

  # create the directory that will serve ACME challenges
  mkdir -p .well-known/acme-challenge
  chmod -R 755 .well-known

  # See https://github.com/lukas2511/letsencrypt.sh/blob/master/docs/domains_txt.md
  echo "example.com www.example.com" > domains.txt

  # See https://github.com/lukas2511/letsencrypt.sh/blob/master/docs/staging.md
  echo "CA=\"https://acme-staging.api.letsencrypt.org/directory\"" > config.sh

  # See https://github.com/lukas2511/letsencrypt.sh/blob/master/docs/wellknown.md
  echo "WELLKNOWN=\"$SSL_ROOT/.well-known/acme-challenge\"" >> config.sh

  # fetch stable version of letsencrypt.sh
  curl "https://raw.githubusercontent.com/lukas2511/letsencrypt.sh/v0.1.0/letsencrypt.sh" > letsencrypt.sh
  chmod 755 letsencrypt.sh
}

# creates self-signed SSL files
# these files are used in development and get production up and running so letsencrypt.sh can do its work
create_pems() {
  openssl req -x509 -nodes -days 730 -newkey rsa:1024 -keyout privkey.pem -out fullchain.pem -subj "/C=US/ST=Anystate/L=Anywhere/O=Initech/OU=Software/CN=dockerhost"
  openssl dhparam -out dhparam.pem 2048
  chmod 600 *.pem
}

# if we have not already done so initialize Docker volume to hold SSL files
if [ ! -d "$SSL_CERT_HOME" ]; then
  mkdir -p $SSL_CERT_HOME
  chmod 755 $SSL_ROOT
  chmod -R 700 $SSL_ROOT/certs
  cd $SSL_CERT_HOME
  create_pems
  cd $SSL_ROOT
  setup_letsencrypt
fi

# if we are configured to run SSL with a real certificate authority run letsencrypt.sh to retrieve/renew SSL certs
if [ "$CA_SSL" = "true" ]; then

  # Nginx must be running for challenges to proceed
  # run in daemon mode so our script can continue
  nginx

  # retrieve/renew SSL certs
  ./letsencrypt.sh --cron

  # copy the fresh certs to where Nginx expects to find them
  cp $SSL_ROOT/certs/example.com/fullchain.pem $SSL_ROOT/certs/example.com/privkey.pem $SSL_CERT_HOME

  # pull Nginx out of daemon mode
  nginx -s stop
fi

# start Nginx in foreground so Docker container doesn't exit
nginx -g "daemon off;"
