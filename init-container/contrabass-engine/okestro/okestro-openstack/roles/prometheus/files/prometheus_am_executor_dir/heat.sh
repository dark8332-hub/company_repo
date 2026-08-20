#!/bin/bash
#
# OpenStack Heat policy web-hook url structure:
# http://127.0.0.1/orchestration/v1/<project_id>/stacks/<stack_name>/<stack_id>/resources/<policy_name>/signal
#

echo "################"
echo "AMX_STATUS =" $AMX_STATUS
echo "AMX_ALERT_1_LABEL_serverity =" $AMX_ALERT_1_LABEL_severity
echo "AMX_ALERT_1_LABEL_tenant_stack_name =" $AMX_ALERT_1_LABEL_tenant_stack_name
echo "AMX_ALERT_1_LABEL_tenant_stack_id =" $AMX_ALERT_1_LABEL_tenant_stack_id
echo "################"
if [[ "$AMX_STATUS" != "firing" ]]; then
    exit 0
fi

# Load Openstack credentials
source /root/contrabass-openrc
# issue token
token=$(openstack token issue -c id -f value)

# send upscale signal to OpenStack policy
#if [[ "$AMX_ALERT_1_LABEL_severity" == "upscale" ]]; then

#url="http://127.0.0.1/orchestration/v1/$AMX_ALERT_1_LABEL_tenant_project_id/stacks/$AMX_ALERT_1_LABEL_tenant_stack_name/$AMX_ALERT_1_LABEL_tenant_stack_id/resources/scaleup_policy/signal"


#if [[ "$AMX_ALERT_1_LABEL_severity" == "upscale" ]]; then

#  url="http://192.168.21.180:18004/%\(tenant_id\)s/v1/stacks/test/$AMX_ALERT_1_LABEL_tenant_stack_id/resources/scaleup_policy/signal"
#  curl -s -H "X-Auth-Token: $token" -X POST -i -k $url

#fi

if [[ "$AMX_ALERT_1_LABEL_severity" == "upscale" ]]; then

  url="http://192.168.21.180:18004/v1/%\(tenant_id\)s/stacks/test/abf2e428-4e7c-4f56-a20f-33fe2da63cc6/resources/scaleup_policy/signal"
  curl -s -H "X-Auth-Token: $token" -X POST -i -k $url

fi

if [[ "$AMX_ALERT_1_LABEL_severity" == "downscale" ]]; then

  url="http://192.168.21.180:18004/v1/%\(tenant_id\)s/stacks/test/abf2e428-4e7c-4f56-a20f-33fe2da63cc6/resources/scaledown_policy/signal"
  curl -s -H "X-Auth-Token: $token" -X POST -i -k $url

fi

