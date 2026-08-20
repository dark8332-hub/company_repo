# Okestro Openstack Deploy Init Contanier Files

<hr/>

## 변경사항



	1. 24/05/10 - okestro-openstack:v1.2
	   Octavia Interface 데몬 비정상 동작 수정, Manila https Python 코드 태스크 비정상 동작 수정,
	   ufw,apparmor disable 비정상 동작 수정, masakari-dashboard(Ubuntu) 비정상 동작 수정,
	   Cinder - Ceph 연동 Task 수정
	   기타 컴포넌트 태스크 오타 수정 
	   Swift Task 추가
	   TLS-Mirgation 추가( enable_openstack_tls시 적용)
	   Prometheus, Thanos Task 추가
	   Compute Node 증설 Task 추가
	   Manila - Ceph 연동 Task 추가
	   Okestro-Ansible 수정요청 Spread Sheet 완료 목록
	   - 3,4,5,6,7,8,9,10,11,13,14,16,17

	2. 24/05/31 - openstack-ansible:v1.3
	   Compute Node GPU role 추가 (Test, No Product),
	   Heat Role 에서 heat-init.yml task 편집 -> 'default_project: service' annotation,
	   Prometheus Role 에서 s3cmd template Copy 부분 편집

	3. 24/08/12 - openstack-ansible:v1.4
	   Ansible 구조 전체 변경: Okestro-opesntack과 Ceph-ansible 병합
	   Domain Endpoint 구현 및 TLS 적용 완료
	   Heat Endpoint TLS 적용 완료
	   SSH Key 배포 없이 배포 기능 추가
	   enable_openstack_tls: false 변수 적용시 TLS 기능 동작하지 않게 적용
	   Contrabass Portal All-in-one 배포 가능(Controller#01 container 형태로 배포)
	   배포 가이드는 https://okestro.atlassian.net/wiki/spaces/CT/pages/1592361080/Contrabass+-+Image+v1.4 를 참조 바랍니다.

	4. 25/04/09 - init-container v3.0.2
	   기존 패키징은 ansible 버전에 따른 브랜치 기준으로 패키징 하였으나, 팀 내 정책을 적용하여 혼선을 방지하고자 포탈 버전과 동일하게 브랜치화하여 패키징하기로 협의하였습니다.
	   배포 가이드는 https://okestro.atlassian.net/wiki/spaces/CT/pages/1592361080/Contrabass+-+v3.0.2+Image+v1.4 를 참조 바랍니다.

	5. 25/04/09 - init-container v3.0.3
	   04/09 기준 Contrabass-engine만 기능구현이 완료되어 소스코드 업로드 하였습니다. Contrabass-manager v3.0.3 패키징이 되면 업데이트 예정입니다.
	   Barbican, Thanos 기능 구현 / Add node Certificate 관련 TLS migration / monitoring 관련 인증 불가 에러 해결

	6. 25/06/11 - init-container v3.0.3
	   Contrabass-manager v3.0.3 업로드 완료하였습니다.

	7. 25/06/27 - init-contaier v3.0.4
	   Contrabass-engine v3.0.4 업로드 완료하였습니다.
	   Ubuntu 24.04-1 / Suse 9.4 OS의 Caracal Openstack 배포 지원하며, Yoga버전에 대한 배포는 지원하지 않습니다.
	   Loki 추가 및 Monitoring 용 exporter들이 다수 추가되었습니다.
	   MinIO 서비스가 추가되었으며, Thanos와 Loki에 대한 Object 저장소는 MinIO를 Default로 참조합니다. 더 이상 Swift Object storage를 참조하지 않습니다.
	   Tech-preview 기능이 추가되었습니다 (Instance-ha-script)
	   Suse 9.4 OS의 Masakari는 현재 정상동작 불가능합니다. (8/1 재 패키징 완료 예정)
	   배포 가이드는 https://okestro.atlassian.net/wiki/spaces/CT/pages/1592361080/Contrabass+-+v3.0.4 를 참조 바랍니다.
	   7/15 Contrabass-manager와 Prometheus metric 지표를 정상적으로 가져오지 못하는 이슈를 수정하였습니다.
	   7/29 Suse 9.4 Masakari 비정상 동작 이슈 해결 완료하였습니다.
	   8/20 Suse 9.4의 이슈인 Device order로 인한 Ceph/MinIO 배포관련 코드를 수정하였습니다.
           Device 명을 작성하는 것은 동일하나, Label 및 by-path값으로 변경하여 적용되도록 수정하였으며, 노드 재부팅 이후 재배포에 대한 안정성이 보장 불가하여 인지 바랍니다.
	   OVS Port 등록 간 Vlan tag 값이 적용되도록 개선하였습니다.
	   9/17 RabbitMQ CVE 이슈로 인해 4.1.2버전으로 업그레이드 되었습니다.
	   11/3 Mole 버전을 3.0.4 -> 3.0.4.22로 패키징하였습니다.
	   HA고도화를 위한 설정 및 Mole Exporter 기능 추가 등을 통한 Prometheus 업데이트 되었습니다.




# Compute Node 증설 Ansible 사용법

## inventory/inventory.ini 파일 수정
```
[alls]      
...     
new-compute ansible_host=x.x.x.x ansible_user=root #추가     
     
[openstack]     
...     
     
[controller]     
...     
     
[compute]     
...     
     
[new-compute] #추가     
new-compute #추가     
```
          
<hr/>

## Ansible-playbook

ansible-playbook -i inventory/inventory.ini addnode.yml
