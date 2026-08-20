#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/var/lib/textfile_collector"

bash "$BASE_DIR/contrabass_gpu_info.sh"
bash "$BASE_DIR/contrabass_mig_profile_info.sh"
bash "$BASE_DIR/contrabass_vgpu_vm_info.sh"