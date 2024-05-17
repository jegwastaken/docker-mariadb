#!/bin/bash

# exit if no .env file
if [ ! -f .env ]; then
  echo "No .env file found. Exiting..."
  exit 1
fi

# shellcheck source=/dev/null
. .env

volumes=''
network=''
mariadb_data_dir='./data'

# Volumes
if [ -n "${NAMED_VOLUME}" ]; then
  mariadb_data_dir=${NAMED_VOLUME}
  volumes="
volumes:
  ${NAMED_VOLUME}:
"
fi

# Networks
if [ -n "${NETWORKS_DEFAULT_EXTERNAL_NAME}" ]; then
  network="
networks:
  default:
    name: ${NETWORKS_DEFAULT_EXTERNAL_NAME}
    external: true
"
fi

# Generate random password if not set
if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
  # Generate a random password
  MYSQL_ROOT_PASSWORD=$(
    tr -dc A-Za-z0-9 </dev/urandom | head -c 20
    echo ''
  )
  echo "Generated MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}"
fi

# Docker Compose file
cat >docker-compose.yml <<EOF
services:
  ${MARIADB_ID}:
    image: mariadb:10
    restart: unless-stopped
    container_name: ${MARIADB_ID}
    volumes:
      - ./backup:/backup
      - ${mariadb_data_dir}:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_INITDB_SKIP_TZINFO: 1
  ${MARIADB_ID}_phpmyadmin:
    image: phpmyadmin/phpmyadmin:5
    restart: unless-stopped
    container_name: ${MARIADB_ID}_phpmyadmin
    volumes:
      - ./php/custom.ini:/usr/local/etc/php/conf.d/custom.ini
      - ./php/config.user.inc.php:/etc/phpmyadmin/config.user.inc.php
    depends_on:
      - ${MARIADB_ID}
    environment:
      PMA_HOST: ${MARIADB_ID}:3306
      VIRTUAL_HOST: ${PHPMYADMIN_DOMAIN}
      LETSENCRYPT_HOST: ${PHPMYADMIN_DOMAIN}
${volumes}${network}
EOF

# Backup script
cat >_backup.sh <<EOF
#!/bin/bash

docker exec -it ${MARIADB_ID} bash -c 'tar cvf /backup/data-\$(date "+%Y.%m.%d-%I.%M.%S").tar /var/lib/mysql'
EOF

# phpMyAdmin Config
cat >php/config.user.inc.php <<EOF
<?php
\$cfg['AllowUserDropDatabase'] = true;
\$cfg['Servers'][1]['hide_db'] = 'mysql|information_schema|performance_schema';
\$cfg['MysqlSslWarningSafeHosts'] = ['${MARIADB_ID}:3306'];
EOF
