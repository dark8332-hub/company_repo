#Viola 배포 시 vm 스펙 변수
#tofu apply -var-file="viola.tfvars" 사용
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
