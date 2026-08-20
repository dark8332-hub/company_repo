#vm 생성-------------------------------------------------------
#vm 생성
resource "openstack_compute_instance_v2" "create_vm" {
  for_each = { for x in local.root_volume_pairs : x.key => x }
  name              = join("_", compact([trimspace(var.group_base_name), "${each.value.spec.name}${each.value.spec.vm_num == 1 ? "" : "${each.value.idx + 1}"}"]))
  flavor_id         = openstack_compute_flavor_v2.flavors[each.value.spec.name].id
  key_pair          = var.vm_key_pair_name != "" ? var.vm_key_pair_name : null
  availability_zone = var.vm_availability_zone != "" ? var.vm_availability_zone : null
  user_data         = length(trimspace(var.vm_user_data)) > 0 ? base64encode(var.vm_user_data) : null
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.root_volume[each.key].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    port = openstack_networking_port_v2.vm_port_mgmt["${each.value.spec.name}_mgmt_${each.value.idx}"].id
  }
  dynamic "network" {
    for_each = toset([for n in var.add_networks : trimspace(n.network_name) if n.attach_to_vm])
    content {
      port = openstack_networking_port_v2.vm_port_add["${each.value.spec.name}_${network.value}_${each.value.idx}"].id
    }
  }
  depends_on = [
    openstack_compute_flavor_v2.flavors,
    openstack_blockstorage_volume_v3.root_volume,
    openstack_networking_port_v2.vm_port_mgmt,
    openstack_networking_subnet_v2.subnet_mgmt_gw,
    openstack_networking_subnet_v2.subnet_mgmt_no_gw,
    openstack_networking_port_v2.vm_port_add,
    openstack_networking_subnet_v2.subnet_add_gw,
    openstack_networking_subnet_v2.subnet_add_no_gw,
  ]
}
#추가 볼륨 연결
resource "openstack_compute_volume_attach_v2" "add_volume_attach" {
  for_each = { for x in local.add_volume_pairs : x.key => x }
  instance_id = openstack_compute_instance_v2.create_vm[each.key].id
  volume_id   = openstack_blockstorage_volume_v3.add_volume[each.key].id
  depends_on = [
    openstack_compute_instance_v2.create_vm,
    openstack_blockstorage_volume_v3.add_volume,
  ]
}