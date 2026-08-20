#플레이버 생성 ------------------------------------------------
#플레이버 생성
resource "openstack_compute_flavor_v2" "flavors" {
  for_each = { for i in local.flavors_merged : i.name => i }
  name        = join("_", compact([trimspace(var.group_base_name), "${each.value.name}_flavor"]))
  ram         = each.value.ram_mb
  vcpus       = each.value.vcpus
  disk        = 0
  is_public   = false
}
# 플레이버 접근 권한 설정
resource "openstack_compute_flavor_access_v2" "flavors_access" {
  for_each = openstack_compute_flavor_v2.flavors
  flavor_id = each.value.id
  tenant_id = data.openstack_identity_project_v3.access_admin.id
}