#!/bin/sh

ROOT_DIR=/usr/share/nginx/html

# Replace env vars in files served by NGINX
for file in $ROOT_DIR/js/*.js* $ROOT_DIR/index.html $ROOT_DIR/remoteEntry.js;
do
    sed -i 's|VUE_APP_KEYCLOAK_LOGOUT_URL_PLACEHOLDER|'${VUE_APP_KEYCLOAK_LOGOUT_URL}'|g' $file
    sed -i 's|VUE_APP_KEYCLOAK_CLIENT_ID_PLACEHOLDER|'${VUE_APP_KEYCLOAK_CLIENT_ID}'|g' $file
    sed -i 's|BASE_URL_PLACEHOLDER|'${BASE_URL}'|g' $file
    sed -i 's|https:/\/\maestro-admin.okestro.cloud|'${BASE_URL}'|g' $file
    sed -i 's|MAESTRO CMP - Admin|Contrabass|g' $file
    sed -i 's|VUE_APP_HOME_ROUTE_PATH|'${VUE_APP_HOME_ROUTE_PATH}'|g' $file
    # Your other variables here...
done
# Let container execution proceed
exec "$@"

