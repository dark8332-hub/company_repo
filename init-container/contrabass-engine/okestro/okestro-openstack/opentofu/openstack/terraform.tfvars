#오픈스택 연결 정보----------------------------------------------
openstack_keystone_ip = "172.18.52.20"
openstack_user_name   = "admin"
openstack_password    = "cloud1234"
openstack_tenant_name = "admin"
openstack_domain_name = "Default"
openstack_region      = "RegionOne"
openstack_insecure    = true
#--------------------------------------------------------------
#vm 그룹 이름 설정----------------------------------------------
group_base_name = "" #설정 시 볼륨 이름, 플레이버 이름, 보안 그룹 이름에 접두사로 추가

#이미지업로드---------------------------------------------------
image_name       = "Contrabass_image"
upload_image     = "noble-qemu-okestro2018.qcow2" #image/ 폴더에 있는 이미지 파일명
image_visibility = "public"     # "public", "private", "community", "shared"
#--------------------------------------------------------------

# 보안 그룹------------------------------------------------------
sg_ingress_cidr = ["0.0.0.0/0",]

#--------------------------------------------------------------

#네트워크 생성 변수---------------------------------------------
mgmt_network_name     = "vm_mgmt"
mgmt_network_type     = "vlan" #"flat", "vlan"
mgmt_physical_network = "mgmt"
mgmt_vlan_id          = 1851 #network_type이 vlan일 경우 필수, network_type이 flat일 경우 무시됨. 1~4094 사이의 정수여야 함
mgmt_mtu              = 1500

mgmt_subnet_name = "vm_mgmt_subnet" #비우면 기본 id값으로 생성
mgmt_subnet_cidr = "172.18.51.0/24"
mgmt_gateway     = "172.18.51.1"

mgmt_network_dhcp   = true
mgmt_ip_pools_start = "172.18.51.101"
mgmt_ip_pools_end   = "172.18.51.200"
mgmt_dns_ip         = ["172.31.120.1"]
# mgmt_network_routes = [
#   { 
#     destination_cidr = "172.18.54.0/24"
#     next_hop = "172.18.54.1"
#   },
# ]

# 추가할 Neutron 네트워크(여러 개 가능)
add_networks = [
  {
    attach_to_vm     = true #VM에 포트 연결 여부. false인 경우 네트워크만 생성
    network_name     = "vm_api"
    network_type     = "vlan" #"flat", "vlan"
    physical_network = "mgmt"
    vlan_id          = 1852 #network_type이 vlan일 경우 필수, network_type이 flat일 경우 무시됨. 1~4094 사이의 정수여야 함
    mtu              = 1500
    subnet_name      = "vm_api_subnet" #비우면 기본 id값으로 생성
    subnet_cidr      = "172.18.52.0/24"
    gateway          = ""
    enable_dhcp      = true
    ip_pools_start   = "172.18.52.101"
    ip_pools_end     = "172.18.52.200"
    dns_ip           = []
    routes           = [
#   { 
#     destination_cidr = "172.18.52.0/24"
#     next_hop = "172.18.52.1"
#   },
#   { 
#     destination_cidr = "172.19.52.0/24"
#     next_hop = "172.18.52.1"
#   },
    ]
  },
  {
    attach_to_vm     = false #VM에 포트 연결 여부. false인 경우 네트워크만 생성
    network_name     = "vm_storage"
    network_type     = "vlan" #"flat", "vlan" 
    physical_network = "service"
    vlan_id          = 1853 #network_type이 vlan일 경우 필수, network_type이 flat일 경우 무시됨. 1~4094 사이의 정수여야 함
    mtu              = 1500
    subnet_name      = "vm_storage_subnet" #비우면 기본 id값으로 생성
    subnet_cidr      = "172.18.53.0/24"
    gateway          = "172.18.53.1"
    enable_dhcp      = true
    ip_pools_start   = "172.18.53.101"
    ip_pools_end     = "172.18.53.200"
    dns_ip           = ["172.31.120.1"]
    routes           = [
    # { 
    #   destination_cidr = "192.168.53.0/24"
    #   next_hop = "172.18.53.1"
    # },
    # { 
    #   destination_cidr = "192.168.53.0/24"
    #   next_hop = "172.18.53.1"
    # },
    ]
  },
]
#--------------------------------------------------------------

# VM 스펙------------------------------------------------------
vm_spec = [
  {
    name        = "Master"
    vm_num      = 3
    vcpus       = 4
    ram_mb      = 1024 * 8
    disk_gb     = 100
    add_disk_gb = 0
    mgmt_ip = ["172.18.51.111","172.18.51.112","172.18.51.113"] #mgmt network의 ip 리스트. vm_rum 개수보다 적으면 dhcp로 자동할당
    mgmt_vip    = "172.18.51.100" #해당 vm들의 vip
    add_ip = { #add_network의 network_name을 입력
      api = ["172.18.52.111", "172.18.52.112", "172.18.52.113"] 
      
      }
    add_vip = {
      api = "172.18.52.100"
    }
  },
  {
    name        = "Infra"
    vm_num      = 3
    vcpus       = 6
    ram_mb      = 1024 * 16
    disk_gb     = 100
    add_disk_gb = 200
    mgmt_ip = ["172.18.51.114","172.18.51.115","172.18.51.116"] #mgmt network의 ip 리스트. vm_rum 개수보다 적으면 dhcp로 자동할당
    add_ip = { #add_network의 network_name을 입력
      api = ["172.18.52.114", "172.18.52.115", "172.18.52.116"] 
      
      }
  },
  {
    name        = "Manager"
    vm_num      = 2
    vcpus       = 6
    ram_mb      = 1024 * 16
    disk_gb     = 100
    add_disk_gb = 0
    mgmt_ip = ["172.18.51.117","172.18.51.118"] #mgmt network의 ip 리스트. vm_rum 개수보다 적으면 dhcp로 자동할당
    add_ip = { #add_network의 network_name을 입력
      api = ["172.18.52.117", "172.18.52.118"] 
      
      }
  },
  {
    name        = "Backup"
    vm_num      = 1
    vcpus       = 4
    ram_mb      = 1024 * 8
    disk_gb     = 500
    add_disk_gb = 0
    mgmt_ip = ["172.18.51.119",] #mgmt network의 ip 리스트. vm_rum 개수보다 적으면 dhcp로 자동할당
    add_ip = { #add_network의 network_name을 입력
      api = ["172.18.52.119"] 
      
      }
  },
  {
    name        = "Deploy"
    vm_num      = 1
    vcpus       = 4
    ram_mb      = 1024 * 8
    disk_gb     = 500
    add_disk_gb = 0
    mgmt_ip = ["172.18.51.120",] #mgmt network의 ip 리스트. vm_rum 개수보다 적으면 dhcp로 자동할당
    add_ip = { #add_network의 network_name을 입력
      api = ["172.18.52.120"] 
      
      }
  },

]


vm_user_data = <<EOF
#cloud-config

EOF
#--------------------------------------------------------------

# VM configration------------------------------------------------------
vm_key_pair_name     = ""
vm_availability_zone = ""