#보안 그룹 생성 --------------------------------------------
#보안 그룹 생성
resource "openstack_networking_secgroup_v2" "contrabase_sg" {
  name        = join("_", compact([trimspace(var.group_base_name), "security_group"]))
  description = "Created By OpenFofu"
}
#보안 그룹 인그레스 정책 생성
resource "openstack_networking_secgroup_rule_v2" "ingress" {
  for_each = toset([for c in var.sg_ingress_cidr : trimspace(c) if trimspace(c) != ""])
  direction           = "ingress"
  ethertype           = "IPv4"
  security_group_id   = openstack_networking_secgroup_v2.contrabase_sg.id
  remote_ip_prefix    = each.value
}