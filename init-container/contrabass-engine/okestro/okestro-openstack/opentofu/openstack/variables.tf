#오픈스택 연결 정보----------------------------------------------
variable "openstack_keystone_ip" {
    type        = string
    description = "OpenStack Identity (Keystone) v3 auth ip"

    validation {
      condition     = length(trimspace(var.openstack_keystone_ip)) > 0
      error_message = "openstack_keystone_ip의 값이 없습니다."
    }
  }

variable "openstack_user_name" {
    type        = string
    description = "OpenStack username"

    validation {
      condition     = length(trimspace(var.openstack_user_name)) > 0
      error_message = "openstack_user_name의 값이 없습니다."
    }
  }

variable "openstack_password" {
    type        = string
    description = "OpenStack password"
    sensitive   = true

    validation {
      condition     = length(trimspace(var.openstack_password)) > 0
      error_message = "openstack_password의 값이 없습니다."
    }
  }

variable "openstack_tenant_name" {
    type        = string
    description = "OpenStack project/tenant name"
    default     = "admin"
  }

variable "openstack_domain_name" {
    type        = string
    description = "OpenStack domain name"
    default     = "Default"
  }

variable "openstack_region" {
    type        = string
    description = "OpenStack region name"
    default     = "RegionOne"
  }

variable "openstack_insecure" {
    type        = bool
    description = "Skip TLS verification (self-signed/internal CA; dev/internal only)"
    default     = true
  }

#vm 그룹 이름 설정----------------------------------------------
variable "group_base_name" {
  type        = string
  description = "vm 그룹 접두 이름"
  default     = ""
}

#이미지업로드---------------------------------------------------
variable "image_name" {
    type        = string
    description = "Glance 이미지 표시 이름"
}

variable "upload_image" {
    type        = string
    description = "Glance 이미지 표시 이름"

  validation {
    condition     = length(trimspace(var.upload_image)) > 0
    error_message = "upload_image의 값이 없습니다."
  }
}

variable "image_container_format" {
    type        = string
    description = "컨테이너 포맷 (예: bare)"
    default     = "bare"
}

variable "image_disk_format" {
    type        = string
    description = "디스크 포맷 (예: qcow2, raw)"
    default     = "qcow2"
}

variable "image_visibility" {
    type        = string
    description = "이미지 공개 범위: public, private, shared, community"
    default     = "public"

    validation {
    condition     = contains(["public", "private", "shared", "community"], var.image_visibility)
    error_message = "image_visibility 은 public, private, shared, community 만 허용됩니다."
  }
}

#vm 스펙 변수--------------------------------------------------
variable "vm_spec" {
  description = "vm 스펙 목록"
  type = list(object({
    name        = string
    vm_num      = number
    vcpus       = number
    ram_mb      = number
    disk_gb     = number
    add_disk_gb = optional(number)
    mgmt_ip     = list(string)
    mgmt_vip    = optional(string, "")
    add_ip  = optional(map(list(string)), {})
    add_vip = optional(map(string), {})
  }))
  default = []

  validation {
    condition     = length([for s in var.vm_spec : s.name]) == length(distinct([for s in var.vm_spec : s.name]))
    error_message = "vm_spec 의 name 은 서로 달라야 합니다."
  }

  validation {
    condition = alltrue([
      for s in var.vm_spec : s.vcpus > 0 && s.ram_mb > 0 && s.disk_gb > 0
    ])
    error_message = "instance의 vm_num, vcpus, ram_mb, disk_gb 는 모두 0보다 커야 합니다."
  }
}

# 보안 그룹 생성 ------------------------------------------------
variable "sg_ingress_cidr" {
  type        = list(string)
  description = "contrabase_sg IPv4 인그레스 허용 CIDR 목록. 빈 리스트 []이면 보안 그룹만 생성하고 인그레스 규칙은 만들지 않음"
  default     = []

  validation {
    condition = alltrue([
      for c in var.sg_ingress_cidr : can(cidrhost(trimspace(c), 0))
    ])
    error_message = "sg_ingress_cidr는 비어 있거나 유효한 CIDR 표기여야 합니다. [\"0.0.0.0/0\",]"
  }
}

#네트워크 생성 변수----------------------------------------------
variable "mgmt_network_name" {
  type        = string
  description = "생성할 vm mgmt 네트워크 이름"
  default     = ""
}

variable "mgmt_network_type" {
  type        = string
  description = "Neutron 프로바이더 세그먼트 타입: flat 또는 vlan"

  validation {
    condition     = contains(["flat", "vlan"], var.mgmt_network_type)
    error_message = "network_type은 flat 또는 vlan 만 허용됩니다."
  }
}

variable "mgmt_physical_network" {
  type        = string
  description = "vm mgmt 물리 네트워크 이름 (ML2 bridge_mappings physnet)"
  
  validation {
    condition     = length(trimspace(var.mgmt_physical_network)) > 0
    error_message = "mgmt_physical_network의 값이 없습니다."
  }
}

variable "mgmt_vlan_id" {
  type        = number
  description = "network_type 가 vlan 일 때 VLAN ID(1-4094). flat 일 때는 add에 전달되지 않음"
  default     = null

  validation {
    condition = (
      var.mgmt_network_type != "vlan" ||
      (var.mgmt_vlan_id != null && var.mgmt_vlan_id >= 1 && var.mgmt_vlan_id <= 4094)
    )
    error_message = "mgmt_network_type이 vlan입니다. mgmt_vlan_id는 1~4094의 정수여야 합니다."
  }
}

variable "mgmt_mtu" {
  type        = number
  description = "MGMT Network MTU"
  default     = 1500

  validation {
    condition     = var.mgmt_mtu > 0 && var.mgmt_mtu < 65536
    error_message = "mgmt_mtu는 1~65535 이어야 합니다."
  }
}

variable "mgmt_subnet_name" {
  type        = string
  description = "서브넷 리소스 이름"
  default     = ""
}

variable "mgmt_subnet_cidr" {
  type        = string
  description = "서브넷 CIDR"

  validation {
    condition     = can(cidrhost(trimspace(var.mgmt_subnet_cidr), 0))
    error_message = "mgmt_subnet_cidr는 유효한 CIDR 표기여야 합니다."
  }
}

variable "mgmt_gateway" {
  type        = string
  description = "MGMT 서브넷 게이트웨이 IP. 빈 문자열/공백만 있으면 게이트웨이 비활성화(no_gateway)"
  default     = ""
}

variable "mgmt_network_dhcp" {
  type        = bool
  description = "DHCP 사용 여부"
  default     = false
}

variable "mgmt_ip_pools_start" {
  type        = string
  description = "DHCP/포트 할당용 IP 풀 시작점"
  default     = ""
}
variable "mgmt_ip_pools_end" {
  type        = string
  description = "DHCP/포트 할당용 IP 풀 끝점"
  default     = ""
}
variable "mgmt_dns_ip" {
  type        = list(string)
  description = "서브넷 DNS 서버 목록"
  default     = []
}

variable "mgmt_network_routes" {
  type = list(object({
    destination_cidr = string
    next_hop         = string
  }))
  description = "mgmt network route"
  default     = []
}

variable "add_networks" {
  description = "추가 Neutron 네트워크 목록. network_name 이 for_each·vm_spec.add_ip 맵 키로 쓰인다. attach_to_vm=true 만 VM 포트·NIC 연결."
  type = list(object({
    network_name     = string
    network_type     = string
    physical_network = string
    vlan_id          = optional(number)
    mtu              = optional(number, 1500)
    subnet_name      = string
    subnet_cidr      = string
    gateway          = optional(string, "")
    enable_dhcp      = optional(bool, false)
    ip_pools_start   = optional(string, "")
    ip_pools_end     = optional(string, "")
    dns_ip           = optional(list(string), [])
    routes = optional(list(object({
      destination_cidr = string
      next_hop         = string
    })), [])
    attach_to_vm = bool
  }))
  default = []

  validation {
    condition = length([for n in var.add_networks : trimspace(n.network_name)]) == length(distinct([
      for n in var.add_networks : trimspace(n.network_name)
    ]))
    error_message = "add_networks 의 network_name 은 trim 후 서로 달라야 합니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks : contains(["flat", "vlan"], n.network_type)
    ])
    error_message = "add_networks[].network_type 은 flat 또는 vlan 만 허용됩니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks :
      n.network_type != "vlan" || (n.vlan_id != null && n.vlan_id >= 1 && n.vlan_id <= 4094)
    ])
    error_message = "add_networks 에서 network_type 이 vlan 일 때 vlan_id 는 1~4094 여야 합니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks : length(trimspace(n.physical_network)) > 0
    ])
    error_message = "add_networks[].physical_network 은 비어 있을 수 없습니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks :
      length(trimspace(n.network_name)) > 0 && length(trimspace(n.subnet_name)) > 0
    ])
    error_message = "add_networks[].network_name 과 subnet_name 은 비어 있을 수 없습니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks : can(cidrhost(trimspace(n.subnet_cidr), 0))
    ])
    error_message = "add_networks[].subnet_cidr 는 유효한 CIDR 표기여야 합니다."
  }

  validation {
    condition = alltrue([
      for n in var.add_networks : n.mtu > 0 && n.mtu < 65536
    ])
    error_message = "add_networks[].mtu 는 1~65535 이어야 합니다."
  }
}

# vm 설정 --------------------------------------------------
variable "vm_key_pair_name" {
  type        = string
  description = "Nova 키페어 이름"
  default     = ""
}

variable "vm_availability_zone" {
    type        = string
    description = "가용 영역"
    default     = ""
  }

variable "vm_user_data" {
  type        = string
  description = "모든 VM에 공통 적용할 Nova user_data"
  default     = ""
  sensitive   = true
}