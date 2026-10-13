#!/usr/bin/env bash
# INVENTARIS KOMPUTER LINUX V1 - Ubuntu
# Payload sesuai invcpu.gs V6. Tidak mengirim IP Address/Gateway.
set -u
set -o pipefail
WEB_APP_URL="https://script.google.com/macros/s/AKfycbxgisOungxy6BFG3F20VA_xCrAucobxqYGYljO5sk5SpHYO3_MhyYKu5dlCXf-KOxOCRw/exec"

clean(){ local v="${1:-}"; v="$(printf '%s' "$v" | tr '\r\n' '  ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"; [[ -n "$v" ]] && printf '%s' "$v" || printf '%s' '-'; }
read_file(){ [[ -r "$1" ]] && clean "$(cat "$1" 2>/dev/null)" || printf '%s' '-'; }

for c in python3 curl hostname awk sed tr; do
  command -v "$c" >/dev/null 2>&1 || { echo "ERROR: Perintah $c belum tersedia."; exit 1; }
done

computer_name="$(clean "$(hostname 2>/dev/null)")"
manufacturer="$(read_file /sys/class/dmi/id/sys_vendor)"
model="$(read_file /sys/class/dmi/id/product_name)"
serial="$(read_file /sys/class/dmi/id/product_serial)"
case "${serial^^}" in ""|"-"|"TO BE FILLED BY O.E.M."|"TO BE FILLED BY OEM"|"DEFAULT STRING"|"SYSTEM SERIAL NUMBER"|"UNKNOWN"|"NONE"|"NOT SPECIFIED") serial="-";; esac

cpu="$(LC_ALL=C lscpu 2>/dev/null | awk -F: '/^Model name:/ {sub(/^[ \t]+/,"",$2); print $2; exit}')"
cpu="$(clean "$cpu")"
core="$(LC_ALL=C lscpu -p=CORE,SOCKET 2>/dev/null | awk -F, '!/^#/ && NF>=2 {print $1 "," $2}' | sort -u | wc -l | tr -d ' ')"
thread="$(LC_ALL=C lscpu -p=CPU 2>/dev/null | awk '!/^#/ && NF {n++} END {print n+0}')"
[[ "$core" == "0" ]] && core="-"
[[ "$thread" == "0" ]] && thread="-"
ram="$(clean "$(awk '/MemTotal:/ {printf "%.1f GB", $2/1048576}' /proc/meminfo 2>/dev/null)")"

storage="-"
if command -v lsblk >/dev/null 2>&1; then
 storage="$(lsblk -dn -o NAME,SIZE,TYPE,MODEL 2>/dev/null | awk '$3=="disk" {m=""; for(i=4;i<=NF;i++) m=m (i==4?"":" ") $i; x=$1 " " $2; if(m!="") x=x " (" m ")"; printf "%s%s", sep, x; sep=" + "} END {if(sep=="") print "-"}')"
fi
storage="$(clean "$storage")"

gpu="-"
if command -v lspci >/dev/null 2>&1; then
 gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller|Display controller/ {sub(/^[^:]*: /,""); printf "%s%s", sep, $0; sep=" + "} END {if(sep=="") print "-"}')"
fi
gpu="$(clean "$gpu")"

mac="-"
for p in /sys/class/net/*; do
 [[ -r "$p/address" ]] || continue
 iface="${p##*/}"
 [[ "$iface" == "lo" ]] && continue
 case "$iface" in docker*|veth*|virbr*|br-*|tun*|tap*|wg*|zt*|tailscale*) continue;; esac
 [[ -e "$p/device" ]] || continue
 candidate="$(cat "$p/address" 2>/dev/null || true)"
 if [[ -n "$candidate" && "$candidate" != "00:00:00:00:00:00" ]]; then mac="$candidate"; break; fi
done
mac="$(clean "$mac")"
operating_system="-"
if [[ -r /etc/os-release ]]; then operating_system="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-${NAME:-Ubuntu}}")"; fi
operating_system="$(clean "$operating_system")"

echo
echo "========== INVENTARIS KOMPUTER LINUX V1 =========="
printf '%-18s: %s\n' "Computer Name" "$computer_name"
printf '%-18s: %s\n' "Manufacturer" "$manufacturer"
printf '%-18s: %s\n' "Model" "$model"
printf '%-18s: %s\n' "Asset/Serial ID" "$serial"
printf '%-18s: %s\n' "CPU" "$cpu"
printf '%-18s: %s\n' "Core" "$core"
printf '%-18s: %s\n' "Thread" "$thread"
printf '%-18s: %s\n' "RAM" "$ram"
printf '%-18s: %s\n' "Storage" "$storage"
printf '%-18s: %s\n' "GPU" "$gpu"
printf '%-18s: %s\n' "MAC Address" "$mac"
printf '%-18s: %s\n' "Operating System" "$operating_system"
read -r -p "Nama pengguna PC: " user_name
user_name="$(clean "$user_name")"

payload="$(COMPUTER_NAME="$computer_name" MANUFACTURER="$manufacturer" MODEL="$model" SERIAL="$serial" CPU_NAME="$cpu" CORE_COUNT="$core" THREAD_COUNT="$thread" RAM_INFO="$ram" STORAGE_INFO="$storage" GPU_INFO="$gpu" MAC_ADDR="$mac" OS_INFO="$operating_system" USER_NAME="$user_name" python3 - <<'PY'
import json, os
print(json.dumps({
 "computerName":os.getenv("COMPUTER_NAME","-"),
 "manufacturer":os.getenv("MANUFACTURER","-"),
 "model":os.getenv("MODEL","-"),
 "assetSerialID":os.getenv("SERIAL","-"),
 "cpu":os.getenv("CPU_NAME","-"),
 "core":os.getenv("CORE_COUNT","-"),
 "thread":os.getenv("THREAD_COUNT","-"),
 "ram":os.getenv("RAM_INFO","-"),
 "storage":os.getenv("STORAGE_INFO","-"),
 "gpu":os.getenv("GPU_INFO","-"),
 "macAddress":os.getenv("MAC_ADDR","-"),
 "operatingSystem":os.getenv("OS_INFO","-"),
 "userName":os.getenv("USER_NAME","-")
}, ensure_ascii=False))
PY
)" || { echo "ERROR: Gagal membuat JSON."; exit 1; }

echo
echo "IP Address dan Gateway tidak dikumpulkan."
read -r -p "Kirim data ini ke DB-Main/Riwayat? Ketik YA untuk lanjut: " confirm
[[ "$confirm" == "YA" ]] || { echo "Dibatalkan; tidak ada data yang dikirim."; exit 0; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if ! curl -fsSL --max-time 60 -H 'Content-Type: application/json; charset=utf-8' --data-binary "$payload" "$WEB_APP_URL" -o "$tmp"; then
 echo "ERROR: Pengiriman gagal. Periksa koneksi internet dan URL Web App."
 exit 1
fi

python3 - "$tmp" <<'PY'
import json, sys
try:
 d=json.load(open(sys.argv[1], encoding="utf-8"))
 print("Status :", d.get("status","?"))
 print("Pesan  :", d.get("message","-"))
 if d.get("result"): print("Hasil  :", d["result"])
 for x in d.get("changes",[]) or []: print(" -",x)
 if d.get("status") != "OK": sys.exit(2)
except Exception as e:
 print("Respons server bukan JSON yang diharapkan:",e); sys.exit(3)
PY
rc=$?
if [[ "$rc" -ne 0 ]]; then echo "Server melaporkan error; jangan langsung mengulang scan sebelum diperiksa."; exit "$rc"; fi
echo "Selesai."
