#!/bin/bash -ux
# configuration
region="vagrant"
os_rc_file="/opt/himlar/provision/dataporten/openstack.rc.${region}"
domain="dataporten"
idp_name="dataporten"
idp_endpoint="https://auth.feideconnect.no"
mapping_name="dataporten_demo"
mapping_rules="/opt/himlar/provision/dataporten/mapping_demo.json"

# Create domain and demo project
puppet apply --test /opt/himlar/provision/dataporten/dataporten_domain.pp

# Load openstack client credentials and settings
source "${os_rc_file}"

# Create demo group
# check
openstack group list --domain "${domain}" | grep demo
# create
if [[ $? -ne 0 ]]; then
  openstack group create demo --domain "${domain}"
fi

# Give demo group access to demo project
#
# "user" is our own role, "member" and "reader" are the standard RBAC ones.
# New-style service policies, and the ones skyline ships, check role:member to
# change and role:reader to list, so a group holding only "user" can log in to
# skyline and then see nothing. Granting a role is an idempotent PUT in
# keystone, so these run unconditionally and fix up existing environments too.
for role in user member reader; do
  openstack role create --or-show "${role}"
  openstack role add --group demo --group-domain "${domain}" \
    --project demo --project-domain "${domain}" "${role}"
done

# Create idp
# check
openstack identity provider list | grep ${idp_name}
# create
if [[ $? -ne 0 ]]; then
  openstack identity provider create "${idp_name}" --remote-id "${idp_endpoint}"
fi

# Create mapping
# check
openstack mapping list | grep ${mapping_name}
# create
if [[ $? -ne 0 ]]; then
  # Find domain ID
  domain_id=$(openstack domain show $domain -f value -c id)
  # Replace DOMAIN_ID token with real ID in mapping rules
  sed "s/DOMAIN_ID/$domain_id/" "${mapping_rules}" > /tmp/mapping.rules
  openstack mapping create "${mapping_name}" --rules /tmp/mapping.rules
fi

# Create protocol
# check
openstack federation protocol list --identity-provider "${idp_name}" | grep oidc
# create
if [[ $? -ne 0 ]]; then
  openstack federation protocol create oidc --identity-provider "${idp_name}" --mapping "${mapping_name}"
fi

# Destroy the configured objects
param=${1-unset}
if [[ $param == "destroy" ]]; then
  openstack federation protocol delete oidc --identity-provider "${idp_name}"
  openstack mapping delete "${mapping_name}"
  openstack identity provider delete "${idp_name}"
fi

systemctl restart httpd

