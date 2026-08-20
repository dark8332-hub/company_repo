#!/usr/bin/env bash
# /usr/local/bin/collect_contrabass_mig_profile_info.sh
OUT="/var/lib/node-exporter/textfile_collector/contrabass_mig_profile_info.prom"
TMP="$(mktemp)"

mkdir -p "$(dirname "$OUT")"

{
  echo '# HELP contrabass_mig_profile_info MIG profile inventory per GPU'
  echo '# TYPE contrabass_mig_profile_info gauge'

  nvidia-smi mig -lgip 2>/dev/null | awk '
  # 예시 라인:
  # |   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
  #                          ^^^^^^프로필^^^^^  ^ID^  ^Free/Total^  ^MemGiB^  ^P2P^  ^SM^
  /^\|[[:space:]]*[0-9]+[[:space:]]+MIG[[:space:]]/ {
    line=$0
    # GPU index
    if (match(line, /^\|[[:space:]]*([0-9]+)/, g)) gpu=g[1]; else next
    # 프로필/ID/인스턴스/메모리/P2P/SM 추출
    # profile(1), id(2), free(3), total(4), mem(5), p2p(6), sm(7)
    if (match(line, /MIG[[:space:]]([0-9A-Za-z.+]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)\/([0-9]+)[[:space:]]+([0-9.]+)[[:space:]]+([A-Za-z]+)[[:space:]]+([0-9]+)/, m)) {
      profile=m[1]; id=m[2]; free=m[3]; total=m[4]; mem=m[5]; sm=m[7]
      printf "contrabass_mig_profile_info{gpu=\"%s\",MIG_Profile=\"%s\",ID=\"%s\",Instances_Free=\"%s\",Instances_Total=\"%s\",Memory=\"%s\",SM=\"%s\"} 1\n",
             gpu, profile, id, free, total, mem, sm
    }
  }'
} > "$TMP"

install -m 0644 "$TMP" "$OUT"
rm -f "$TMP"
