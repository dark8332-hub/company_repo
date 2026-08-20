#오픈스택 연결 정보---------------------------------------------
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.0"
    }
  }
}
provider "openstack" {
  auth_url    = "https://${var.openstack_keystone_ip}:15000/v3/"
  user_name   = var.openstack_user_name
  password    = var.openstack_password
  tenant_name = var.openstack_tenant_name
  domain_name = var.openstack_domain_name
  region      = var.openstack_region
  insecure    = var.openstack_insecure
}