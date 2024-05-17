<?php
$cfg['AllowUserDropDatabase'] = true;
$cfg['Servers'][1]['hide_db'] = 'mysql|information_schema|performance_schema';
$cfg['MysqlSslWarningSafeHosts'] = ['mariadb:3306'];
