#!/bin/sh

ROOT_DIR=/usr/share/nginx/html/remoteContrabass

# Replace env vars in files served by NGINX
for file in $ROOT_DIR/js/*.js* $ROOT_DIR/index.html $ROOT_DIR/remoteEntry.js;
do
    sed -i 's|BASE_URL_PLACEHOLDER|'${BASE_URL}'|g' $file
    sed -i 's|maestro-admin.okestro.cloud|'contrabass.os:9443'|g' $file
    # Your other variables here...
done
# Let container execution proceed
exec "$@"
