#네트워크 생성  ------------------------------------------------
#mgmt 네트워크 생성
resource "openstack_networking_network_v2" "network_mgmt" {
  name           = var.mgmt_network_name
  admin_state_up = true
  dynamic "segments" {
    for_each = [1]
    content {
      network_type     = var.mgmt_network_type
      physical_network = var.mgmt_physical_network
      segmentation_id  = var.mgmt_network_type == "vlan" ? var.mgmt_vlan_id : null
    }
  }
  mtu = var.mgmt_mtu
}

resource "openstack_networking_subnet_v2" "subnet_mgmt_gw" {
  count = local.mgmt_has_gateway ? 1 : 0

  name        = var.mgmt_subnet_name
  network_id  = openstack_networking_network_v2.network_mgmt.id
  cidr        = var.mgmt_subnet_cidr
  ip_version  = 4
  gateway_ip  = local.mgmt_gateway_trim
  enable_dhcp = var.mgmt_network_dhcp
  allocation_pool {
    start = var.mgmt_ip_pools_start
    end   = var.mgmt_ip_pools_end
  }
  dns_nameservers = length(var.mgmt_dns_ip) > 0 ? var.mgmt_dns_ip : null

  depends_on = [openstack_networking_network_v2.network_mgmt]
}

resource "openstack_networking_subnet_v2" "subnet_mgmt_no_gw" {
  count = local.mgmt_has_gateway ? 0 : 1

  name        = var.mgmt_subnet_name
  network_id  = openstack_networking_network_v2.network_mgmt.id
  cidr        = var.mgmt_subnet_cidr
  ip_version  = 4
  no_gateway  = true
  enable_dhcp = var.mgmt_network_dhcp
  allocation_pool {
    start = var.mgmt_ip_pools_start
    end   = var.mgmt_ip_pools_end
  }
  dns_nameservers = length(var.mgmt_dns_ip) > 0 ? var.mgmt_dns_ip : null

  depends_on = [openstack_networking_network_v2.network_mgmt]
}

resource "openstack_networking_subnet_route_v2" "mgmt" {
  for_each = { for i, r in var.mgmt_network_routes : tostring(i) => r }

  subnet_id        = local.subnet_mgmt_id
  destination_cidr = each.value.destination_cidr
  next_hop         = each.value.next_hop

  depends_on = [
    openstack_networking_subnet_v2.subnet_mgmt_gw,
    openstack_networking_subnet_v2.subnet_mgmt_no_gw,
  ]
}

resource "openstack_networking_port_v2" "vm_port_mgmt" {
  for_each = local.network_ports_mgmt

  name           = each.value.port_name
  network_id     = openstack_networking_network_v2.network_mgmt.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.contrabase_sg.id]

  fixed_ip {
    subnet_id  = local.subnet_mgmt_id
    ip_address = each.value.fixed_ip
  }

  dynamic "allowed_address_pairs" {
    for_each = each.value.mgmt_vip != "" ? [1] : []
    content {
      ip_address = each.value.mgmt_vip
    }
  }

  depends_on = [
    openstack_networking_subnet_v2.subnet_mgmt_gw,
    openstack_networking_subnet_v2.subnet_mgmt_no_gw,
    openstack_networking_secgroup_v2.contrabase_sg,
  ]
}


# add(추가) Neutron 네트워크 — add_networks 리스트로 동적 생성
resource "openstack_networking_network_v2" "network_add" {
  for_each       = local.add_networks_map
  name           = each.value.network_name
  admin_state_up = true
  dynamic "segments" {
    for_each = [1]
    content {
      network_type     = each.value.network_type
      physical_network = each.value.physical_network
      segmentation_id  = each.value.network_type == "vlan" ? each.value.vlan_id : null
    }
  }
  mtu = each.value.mtu
}

resource "openstack_networking_subnet_v2" "subnet_add_gw" {
  for_each = local.add_networks_has_gw

  name        = each.value.subnet_name
  network_id  = openstack_networking_network_v2.network_add[each.key].id
  cidr        = each.value.subnet_cidr
  ip_version  = 4
  gateway_ip  = trimspace(each.value.gateway)
  enable_dhcp = each.value.enable_dhcp
  allocation_pool {
    start = each.value.ip_pools_start
    end   = each.value.ip_pools_end
  }
  dns_nameservers = length(coalesce(each.value.dns_ip, [])) > 0 ? each.value.dns_ip : null

  depends_on = [openstack_networking_network_v2.network_add]
}

resource "openstack_networking_subnet_v2" "subnet_add_no_gw" {
  for_each = local.add_networks_no_gw

  name        = each.value.subnet_name
  network_id  = openstack_networking_network_v2.network_add[each.key].id
  cidr        = each.value.subnet_cidr
  ip_version  = 4
  no_gateway  = true
  enable_dhcp = each.value.enable_dhcp
  allocation_pool {
    start = each.value.ip_pools_start
    end   = each.value.ip_pools_end
  }
  dns_nameservers = length(coalesce(each.value.dns_ip, [])) > 0 ? each.value.dns_ip : null

  depends_on = [openstack_networking_network_v2.network_add]
}

resource "openstack_networking_subnet_route_v2" "add" {
  for_each = { for r in local.add_route_expande : r.id => r }

  subnet_id        = local.subnet_add_id[each.value.network_key]
  destination_cidr = each.value.destination_cidr
  next_hop         = each.value.next_hop

  depends_on = [
    openstack_networking_subnet_v2.subnet_add_gw,
    openstack_networking_subnet_v2.subnet_add_no_gw,
  ]
}

resource "openstack_networking_port_v2" "vm_port_add" {
  for_each = local.network_ports_add

  name           = each.value.port_name
  network_id     = openstack_networking_network_v2.network_add[each.value.network_key].id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.contrabase_sg.id]

  fixed_ip {
    subnet_id  = local.subnet_add_id[each.value.network_key]
    ip_address = each.value.fixed_ip
  }

  dynamic "allowed_address_pairs" {
    for_each = each.value.add_vip != "" ? [1] : []
    content {
      ip_address = each.value.add_vip
    }
  }

  depends_on = [
    openstack_networking_network_v2.network_add,
    openstack_networking_subnet_v2.subnet_add_gw,
    openstack_networking_subnet_v2.subnet_add_no_gw,
    openstack_networking_secgroup_v2.contrabase_sg,
  ]
}