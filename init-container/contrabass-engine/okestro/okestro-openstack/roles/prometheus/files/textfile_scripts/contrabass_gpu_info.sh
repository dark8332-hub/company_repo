#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# 1) 현재 노드의 pGPU 슬롯 목록 수집 (PF만)
# -----------------------------
# 예: pgpu="0000:62:00\n0000:c9:00"
pgpu="${pgpu:-}"

if [[ -z "${pgpu:-}" ]]; then
  pgpu="$(
    for d in /sys/bus/pci/devices/*; do
      # NVIDIA 벤더 + VGA/3D 클래스만
      [[ -f "$d/vendor" && $(<"$d/vendor") == 0x10de ]] || continue
      [[ -f "$d/class"  && $(<"$d/class")  == 0x03*    ]] || continue   # VGA / 3D
      # VF(가상 함수)는 제외
      [[ -e "$d/physfn" ]] && continue

      bn="$(basename "$d")"      # 0000:62:00.0
      echo "${bn%.*}"            # 0000:62:00
    done | sort -u
  )"
fi

# -----------------------------
# 2) 모델명 정규화 함수 (lspci Device: 기준)
#    예: "GH100 [H100L 94GB]" → "H100L 94GB"
#        "NVIDIA Corporation GA100 [A100 PCIe 40GB]" → "A100 PCIe 40GB"
# -----------------------------
_norm_model() {
  local s="$*"

  # 1) "GH100 [H100L 94GB]" → 대괄호 안만 뽑기
  if [[ "$s" =~ \[([^\]]+)\] ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  # 2) 그 외는 앞쪽 NVIDIA 문자열 제거 + 하이픈/PCIE 정리
  s="${s#NVIDIA Corporation }"
  s="${s#NVIDIA }"
  s="${s//-/ }"
  s="${s//PCIE/PCIe}"
  while [[ "$s" == *"  "* ]]; do s="${s//  / }"; done
  s="${s%" "}"
  echo "$s"
}

# -----------------------------
# 3) BDF → VM 매핑 생성 (/etc/libvirt/qemu/*.xml)
# -----------------------------
#  - instance-0000001d.xml 등 persistent 도메인 정의에서
#    <hostdev><source><address domain='0x0000' bus='0x62' slot='0x00' function='0x0'/>
#    를 찾아서 BDF_VM["0000:62:00.0"]="instance-0000001d"
# -----------------------------
declare -gA BDF_VM

for xml in /etc/libvirt/qemu/*.xml; do
  [[ -f "$xml" ]] || continue
  [[ "$xml" != *.xml ]] && continue   # .xml.back 등은 무시

  domname="$(basename "$xml" .xml)"

  # hostdev source address 라인에서 domain/bus/slot/function 추출
  while read -r dom_hex bus_hex slot_hex func_hex; do
    [[ -z "$dom_hex" || -z "$bus_hex" || -z "$slot_hex" || -z "$func_hex" ]] && continue

    # '0x62' → '62'
    dom_raw="${dom_hex#0x}"
    bus_raw="${bus_hex#0x}"
    slot_raw="${slot_hex#0x}"
    func_raw="${func_hex#0x}"

    # 0000 / 62 / 00 / 0 패딩
    dom=$(printf '%04s' "$dom_raw" | tr ' ' '0')
    bus=$(printf '%02s' "$bus_raw" | tr ' ' '0')
    slot=$(printf '%02s' "$slot_raw" | tr ' ' '0')
    func=$(printf '%1s'  "$func_raw" | tr ' ' '0')

    canon="${dom}:${bus}:${slot}.${func}"   # 0000:62:00.0
    BDF_VM["$canon"]="$domname"
  done < <(
    sed -n "s/.*<address[^>]*domain='\(0x[0-9a-fA-F]\+\)'[^>]*bus='\(0x[0-9a-fA-F]\+\)'[^>]*slot='\(0x[0-9a-fA-F]\+\)'[^>]*function='\(0x[0-9a-fA-F]\+\)'.*/\1 \2 \3 \4/p" "$xml" 2>/dev/null
  )
done

# -----------------------------
# 4) Prometheus textfile collector 출력
# -----------------------------
OUT="${OUT:-/var/lib/node-exporter/textfile_collector/contrabass_gpu_info.prom}"
TMP="$(mktemp)"

# 라벨 이스케이프 함수 (", \, 줄바꿈)
__esc_label() {
  local s="$*"
  s="${s//\\/\\\\}"        # \ → \\
  s="${s//\"/\\\"}"        # " → \"
  s="${s//$'\n'/ }"        # newline → space
  printf '%s' "$s"
}

{
  echo '# HELP contrabass_gpu_info NVIDIA GPU inventory (PF only; vm label only for vfio-pci)'
  echo '# TYPE contrabass_gpu_info gauge'

  # PF 슬롯 리스트 순회
  printf '%s\n' "$pgpu" | while read -r slot; do
    [[ -n "$slot" ]] || continue

    canon="$slot.0"   # 0000:62:00 → 0000:62:00.0

    # sysfs에 정말 있는지 확인 (함수번호가 0이 아닐 수 있으면 이 부분 조정)
    if [[ ! -e "/sys/bus/pci/devices/$canon" ]]; then
      canon="$(basename "$(ls /sys/bus/pci/devices/$slot.* 2>/dev/null | head -n1 || true)")"
    fi
    [[ -n "$canon" ]] || continue

    # 현재 바인딩된 드라이버 확인
    drv="none"
    if [[ -L "/sys/bus/pci/devices/$canon/driver" ]]; then
      drv="$(basename "$(readlink -f "/sys/bus/pci/devices/$canon/driver")")"
    fi

    # 모델명: lspci 기반
    model="$(
      lspci -s "${canon#0000:}" -vmm 2>/dev/null \
      | awk -F'\t' "/^Device:/{print \$2; exit}"
    )"
    [[ -z "$model" ]] && model="Unknown"
    model="$(_norm_model "$model")"

    if [[ "$drv" == "vfio-pci" ]]; then
      vm="${BDF_VM[$canon]:--}"

      printf 'contrabass_gpu_info{slot="%s",bdf="%s",module="%s",model="%s",domain="%s"} 1\n' \
        "$(__esc_label "$slot")" \
        "$(__esc_label "$canon")" \
        "$(__esc_label "$drv")" \
        "$(__esc_label "$model")" \
        "$(__esc_label "$vm")"
    else
      printf 'contrabass_gpu_info{slot="%s",bdf="%s",module="%s",model="%s"} 1\n' \
        "$(__esc_label "$slot")" \
        "$(__esc_label "$canon")" \
        "$(__esc_label "$drv")" \
        "$(__esc_label "$model")"
    fi
  done
} > "$TMP"

# 원자적 교체
mv "$TMP" "$OUT"

