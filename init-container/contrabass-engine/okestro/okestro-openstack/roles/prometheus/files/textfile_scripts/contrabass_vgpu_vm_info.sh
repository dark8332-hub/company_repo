#!/usr/bin/env bash
set -euo pipefail

OUT="/var/lib/node-exporter/textfile_collector/contrabass_vgpu_vm_info.prom"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$(dirname "$OUT")"

BUS_IDX="$TMP/bus_idx.map"   # BDF(0000:C9:00.0) -> index
PFINFO="$TMP/pfinfo.map"     # BDF index model
OUTTMP="$TMP/out.prom"

# -----------------------------
# 0) 모델명 정규화 함수 (lspci Device: 문자열용)
# -----------------------------
_norm_model() {
  local s="$*"

  # 1) "GH100 [H100L 94GB]" → "H100L 94GB"
  if [[ "$s" =~ \[([^\]]+)\] ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  # 2) 그 외 대충 정리
  s="${s#NVIDIA Corporation }"
  s="${s#NVIDIA }"
  s="${s//-/ }"
  s="${s//PCIE/PCIe}"
  while [[ "$s" == *"  "* ]]; do s="${s//  / }"; done
  s="${s%" "}"
  echo "$s"
}

# -----------------------------
# 1) BDF -> GPU index 맵 (nvidia-smi)
# -----------------------------
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=pci.bus_id,index --format=csv,noheader 2>/dev/null \
  | awk -F, '{
      bus=$1; idx=$2;
      gsub(/^ +| +$/, "", bus);
      gsub(/^ +| +$/, "", idx);
      if (bus == "") next;
      # bus: 00000000:C9:00.0 또는 0000:C9:00.0 → 항상 0000:C9:00.0 형태로 정규화
      split(bus, a, ":");
      if (length(a[1]) > 4) {
        dom = substr(a[1], length(a[1]) - 3);
      } else {
        dom = a[1];
      }
      canon = toupper(dom ":" a[2] ":" a[3]);
      print canon, idx;
    }' > "$BUS_IDX"
else
  : > "$BUS_IDX"
fi

# -----------------------------
# 2) BDF -> (index, model) 맵 구성 (index: nvidia-smi, model: lspci)
# -----------------------------
> "$PFINFO"
while read -r bdf idx; do
  [[ -z "$bdf" ]] && continue

  # lspci는 lower-case, 도메인 떼고 버스/슬롯만 줘도 동작
  bdf_lc="$(echo "$bdf" | tr 'A-Z' 'a-z')"      # 0000:c9:00.0
  slot_no_domain="${bdf_lc#0000:}"             # c9:00.0

  dev="$(
    lspci -s "$slot_no_domain" -vmm 2>/dev/null \
    | awk -F'\t' '/^Device:/{print $2; exit}'
  )"
  [[ -z "$dev" ]] && dev="Unknown"

  model="$(_norm_model "$dev")"

  printf '%s %s %s\n' "$bdf" "$idx" "$model" >> "$PFINFO"
done < "$BUS_IDX"

# -----------------------------
# 3) nvidia-smi vgpu -q 파싱 + PF 매핑 후 .prom 출력
# -----------------------------
{
  echo '# HELP contrabass_vgpu_vm_info VM vGPU attributes (PF/pGPU mapping, lspci-based model)'
  echo '# TYPE contrabass_vgpu_vm_info gauge'

  awk -v PFINFO="$PFINFO" '
    BEGIN {
      # PFINFO: BDF index model...
      while ((getline < PFINFO) > 0) {
        bdf = $1
        idx = $2
        model = $3
        if (NF > 3) {
          for (i = 4; i <= NF; i++) {
            model = model " " $i
          }
        }
        pf_idx[bdf]   = idx
        pf_model[bdf] = model
      }
      close(PFINFO)
    }

    function esc(s,    t) {
      t = s
      gsub(/\\/,"\\\\",t)
      gsub(/"/,"\\\"",t)
      sub(/^[[:space:]]+/,"",t)
      sub(/[[:space:]]+$/,"",t)
      return t
    }

    # 00000000:C9:00.0 / 0000:C9:00.0 → 0000:C9:00.0
    function canon_bdf(s,   t, a, dom) {
      t = s
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      split(t, a, ":")
      if (length(a[1]) > 4)
        dom = substr(a[1], length(a[1]) - 3)
      else
        dom = a[1]
      return toupper(dom ":" a[2] ":" a[3])
    }

    function flush() {
      if (vm != "" && vgn != "") {
        canon_pf = cur_pf
        pgpu      = (canon_pf in pf_idx)   ? pf_idx[canon_pf]   : ""
        pgpu_name = (canon_pf in pf_model) ? pf_model[canon_pf] : ""

        printf "contrabass_vgpu_vm_info{domain=\"%s\",vgpu_name=\"%s\",guest_driver=\"%s\",license_status=\"%s\",pgpu=\"%s\",pgpu_name=\"%s\",pf=\"%s\"} 1\n",
               esc(vm), esc(vgn), esc(drv), esc(lic), esc(pgpu), esc(pgpu_name), esc(canon_pf)
      }
      vm = ""; drv = ""; lic = ""; vgn = ""
    }

    # "GPU 00000000:C9:00.0" 헤더 → 현재 PF BDF 기억
    /^GPU[[:space:]]+/ {
      if (match($0, /GPU[[:space:]]+([0-9A-Fa-f:.]+)/, m)) {
        cur_pf = canon_bdf(m[1])
      }
      next
    }

    /^[[:space:]]*vGPU ID[[:space:]]*:/            { flush(); next }
    /^[[:space:]]*VM Name[[:space:]]*:/            { vm  = substr($0, index($0,":")+2); next }
    /^[[:space:]]*Guest Driver Version[[:space:]]*:/ { drv = substr($0, index($0,":")+2); next }
    /^[[:space:]]*License Status[[:space:]]*:/     { lic = substr($0, index($0,":")+2); next }
    /^[[:space:]]*vGPU Name[[:space:]]*:/          { vgn = substr($0, index($0,":")+2); next }

    /^$/ { flush() }
    END  { flush() }
  ' <(nvidia-smi vgpu -q 2>/dev/null)

} > "$OUTTMP"

install -m 0644 "$OUTTMP" "$OUT"

