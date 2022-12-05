#!/bin/bash

. .env

volumes=''
network=''
pma_absolute_uri="http://${PHPMYADMIN_DOMAIN}"
mariadb_data_dir='./data'

####################
# Volumes
####################
if [ ! -z ${NAMED_VOLUME} ]
then
mariadb_data_dir=${NAMED_VOLUME}

volumes="$(
cat <<EOF


volumes:
  ${NAMED_VOLUME}:
EOF
)"
fi
####################

####################
# Networks
####################
if [ ! -z ${NETWORKS_DEFAULT_EXTERNAL_NAME} ]
then
network="$(
cat <<EOF


networks:
  default:
    external:
      name: ${NETWORKS_DEFAULT_EXTERNAL_NAME}
EOF
)"
fi
####################

####################
# Absolute URI
####################
if [ ${IS_HTTPS:-false} == true ]
then
pma_absolute_uri="https://${PHPMYADMIN_DOMAIN}"
fi
####################

cat > docker-compose.yml <<EOF
version: '3.3'

services:
  ${MARIADB_ID}:
    image: mariadb:latest
    restart: unless-stopped
    container_name: ${MARIADB_ID}
    volumes:
      - ./backup:/backup
      - ${mariadb_data_dir}:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_INITDB_SKIP_TZINFO: 1
  ${MARIADB_ID}_phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
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
      PMA_ABSOLUTE_URI: ${pma_absolute_uri}${volumes}${network}
EOF

cat > _backup.sh <<EOF
#!/bin/bash

docker exec -it ${MARIADB_ID} bash -c 'tar cvf /backup/data-\$(date "+%Y.%m.%d-%I.%M.%S").tar /var/lib/mysql'
EOF
