#볼륨 생성-----------------------------------------------------
#볼륨 타입 생성
resource "openstack_blockstorage_volume_type_v3" "vol_type" {

  name        = join("_", compact([trimspace(var.group_base_name), "vol_type"]))
  is_public   = false
  description = "Created By OpenFofu"
}

resource "openstack_blockstorage_volume_type_access_v3" "vol_type_tenant_access" {
  volume_type_id = openstack_blockstorage_volume_type_v3.vol_type.id
  project_id     = data.openstack_identity_project_v3.access_admin.id
}

#root 볼륨 생성
  resource "openstack_blockstorage_volume_v3" "root_volume" {
    for_each = { for x in local.root_volume_pairs : x.key => x }

    name          = join("_", compact([trimspace(var.group_base_name), "${each.value.spec.name}${each.value.spec.vm_num == 1 ? "" : "${each.value.idx + 1}"}_vol1"]))
    size          = each.value.spec.disk_gb
    image_id      = openstack_images_image_v2.vm_image.id
    volume_type   = openstack_blockstorage_volume_type_v3.vol_type.id
    depends_on    = [
      openstack_blockstorage_volume_type_v3.vol_type,
      openstack_blockstorage_volume_type_access_v3.vol_type_tenant_access,
      openstack_images_image_v2.vm_image,
    ]
  }
#추가 볼륨 생성
  resource "openstack_blockstorage_volume_v3" "add_volume" {
    for_each = { for x in local.add_volume_pairs : x.key => x }

    name        = join("_", compact([trimspace(var.group_base_name), "${each.value.spec.name}${each.value.spec.vm_num == 1 ? "" : "${each.value.idx + 1}"}_vol2"]))
    size        = each.value.spec.add_disk_gb
    volume_type = openstack_blockstorage_volume_type_v3.vol_type.id
    depends_on  = [
      openstack_blockstorage_volume_type_v3.vol_type,
      openstack_blockstorage_volume_type_access_v3.vol_type_tenant_access,
    ]
  }