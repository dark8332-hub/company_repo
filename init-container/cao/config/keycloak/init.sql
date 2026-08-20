USE mysql;
CREATE user 'keycloak'@'%' identified by 'keycloak';
CREATE user 'keycloak'@'contrabass.os' identified by 'keycloak';

CREATE DATABASE IF NOT EXISTS keycloak;
grant ALL PRIVILEGES on keycloak.* to 'keycloak'@'%';
grant ALL PRIVILEGES on keycloak.* to 'keycloak'@'contrabass.os';

flush privileges;
