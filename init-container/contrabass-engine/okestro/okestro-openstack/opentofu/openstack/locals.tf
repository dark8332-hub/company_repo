#프로젝트 조회
data "openstack_identity_project_v3" "access_admin" {
  name = var.openstack_tenant_name
}

locals {
  #플레이버 목록 생성
  flavors_merged = [
    for s in var.vm_spec : {
      name        = s.name
      is_public   = true
      vcpus       = s.vcpus
      ram_mb      = s.ram_mb
      disk_gb     = s.disk_gb
    } if s.vm_num > 0
  ]

  #mgmt 네트워크 관련 변수 생성
  mgmt_gateway_trim = trimspace(try(var.mgmt_gateway, ""))
  mgmt_has_gateway  = local.mgmt_gateway_trim != ""

  network_ports_mgmt_expanded = flatten([
    for s in var.vm_spec : [
      for idx in range(s.vm_num) : {
        key          = "${s.name}_mgmt_${idx}"
        network_kind = "mgmt"
        port_name    = join("_", compact([trimspace(var.group_base_name), "${s.name}${s.vm_num == 1 ? "" : "${idx + 1}"}_mgmt_port"]))
        fixed_ip     = length(s.mgmt_ip) > idx ? s.mgmt_ip[idx] : null
        mgmt_vip     = trimspace(try(s.mgmt_vip, ""))
      }
    ]
  ])

  network_ports_mgmt = {
    for p in local.network_ports_mgmt_expanded : p.key => p
  }

  subnet_mgmt_id = element(concat(
    openstack_networking_subnet_v2.subnet_mgmt_gw[*].id,
    openstack_networking_subnet_v2.subnet_mgmt_no_gw[*].id,
  ), 0)

  #add 네트워크 관련 변수 생성
  add_networks_map = { for n in var.add_networks : trimspace(n.network_name) => n }
  add_networks_has_gw = {
    for n in var.add_networks : trimspace(n.network_name) => n
    if trimspace(try(n.gateway, "")) != ""
  }
  add_networks_no_gw = {
    for n in var.add_networks : trimspace(n.network_name) => n
    if trimspace(try(n.gateway, "")) == ""
  }

  network_ports_add = {
    for obj in flatten([
      for net in var.add_networks : net.attach_to_vm ? flatten([
        for s in var.vm_spec : [
          for idx in range(s.vm_num) : {
            pk          = "${s.name}_${trimspace(net.network_name)}_${idx}"
            network_key = trimspace(net.network_name)
            port_name   = join("_", compact([trimspace(var.group_base_name), "${s.name}${s.vm_num == 1 ? "" : "${idx + 1}"}_${trimspace(net.network_name)}_port"]))
            fixed_ip = (
              length(lookup(coalesce(s.add_ip, {}), trimspace(net.network_name), [])) > idx ?
              coalesce(s.add_ip, {})[trimspace(net.network_name)][idx] : null
            )
            add_vip = trimspace(lookup(coalesce(s.add_vip, {}), trimspace(net.network_name), ""))
          }
        ]
      ]) : []
    ]) : obj.pk => obj
  }

  add_route_expande = flatten([
    for n in var.add_networks : [
      for i, r in coalesce(n.routes, []) : {
        id               = "${trimspace(n.network_name)}_${i}"
        network_key      = trimspace(n.network_name)
        destination_cidr = r.destination_cidr
        next_hop         = r.next_hop
      }
    ]
  ])

  subnet_add_id = merge(
    { for k, s in openstack_networking_subnet_v2.subnet_add_gw : k => s.id },
    { for k, s in openstack_networking_subnet_v2.subnet_add_no_gw : k => s.id },
  )

  # 볼륨/VM 인스턴스 키
  root_volume_pairs = flatten([
    for s in var.vm_spec : [
      for idx in range(s.vm_num) : {
        key  = "${s.name}_${idx}"
        spec = s
        idx  = idx
      }
    ]
  ])

  add_volume_pairs = flatten([
    for s in var.vm_spec : [
      for idx in range(s.vm_num) : {
        key  = "${s.name}_${idx}"
        spec = s
        idx  = idx
      }
    ] if coalesce(try(s.add_disk_gb, null), 0) > 0
  ])
}
