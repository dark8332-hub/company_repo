#이미지업로드---------------------------------------------------
resource "openstack_images_image_v2" "vm_image" {
  name             = var.image_name
  
  local_file_path  = "${path.module}/image/${var.upload_image}"
  container_format = var.image_container_format
  disk_format      = var.image_disk_format
  visibility = var.image_visibility
  properties = {
    hw_require_fsfreeze = "yes"
    hw_qemu_guest_agent = "yes"
  }
}