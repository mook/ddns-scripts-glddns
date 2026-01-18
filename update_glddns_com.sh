#
#.Distributed under the terms of the GNU General Public License (GPL) version 2.0
#
# script for sending updates to glddns.com
#.2026 github.com/mook
#
# This script is parsed by dynamic_dns_functions.sh inside send_update() function
#
# This uses credentials hard-coded in flash.  Examine the devicetree file for
# the offsets; for the GL-MT3600BE, that looks like:
#
# factory_data {
#   country_code = "Factory", "0x4088";
#   device_cert = "Factory", "0x5000";
#   device_ddns = "Factory", "0x4010";
#   device_mac = "Factory", "0x4000";
#   device_sn = "Factory", "0x4030";
#   device_sn_bak = "Factory", "0x4020";
# };

# This script sets global variables for caching:
# URL_USER URL_PASS GLDDNS_DOMAIN GLDDNS_CERT
local __BOARD __BOARD_DATA __PARTITION_NAME __URL
local __USER_OFFSET __PASS_OFFSET __DOMAIN_OFFSET __CERT_OFFSET

# Board data that is in the OEM device tree, but isn't in the OpenWRT one so we
# hard code them here.  Use "_" to skip cert.
# Unsupported boards:
#   GL-B2200                 Info not found in device tree
#   GL-MV1000                Info not found in device tree
#   GL-S1300                 Info not found in device tree
#   All MIPS-based routers   No device tree available
local __BOARD_DATA_LIST='
BOARD              PARTITION         MAC    SN     DDNS   CERT
glinet,gl-a1300    ART               0x0    0x30   0x10   _
glinet,gl-ap1300   ART               0x0    0x30   0x10   _
glinet,gl-ax1800   0:ART             0x0    0x40   0x20   _
glinet,gl-axt1800  0:ART             0x0    0x40   0x20   _
glinet,gl-b1300    ART               0x0    0x30   0x10   _
glinet,gl-b3000    0:ART             0x6    0x30   0x10   0x50000
glinet,gl-be3600   0:ART             0x6    0x30   0x10   0x50000
glinet,gl-be6500   0:ART             0x0a   0x30   0x10   0x80000
glinet,gl-be9300   /dev/mmcblk0p8    0x0a   0x30   0x10   0x80000
glinet,gl-mt2500   /dev/mmcblk0boot1 0x0a   0x30   0x10   _
glinet,gl-mt3000   Factory           0x0a   0x30   0x10   0x1000
glinet,gl-mt3600be Factory           0x4000 0x4030 0x4010 0x5000
glinet,gl-mt5000   /dev/mmcblk0p2    0x4000 0x4030 0x4010 0x5000
glinet,gl-mt6000   /dev/mmcblk0p2    0x0a   0x30   0x10   0x1000
glinet,gl-x2000    0:ART             0x6    0x30   0x10   0x50000
glinet,gl-x3000    /dev/mmcblk0p3    0x0a   0x30   0x10   0x1000
glinet,gl-xe3000   /dev/mmcblk0p3    0x0a   0x30   0x10   0x1000
'

if [ -z "${GLDDNS_DOMAIN:-}" ]; then
  read -r __BOARD < <(ubus call system board | jsonfilter -e '@.board_name')
  while read -r __BOARD_DATA __PARTITION_NAME __USER_OFFSET __PASS_OFFSET __DOMAIN_OFFSET __CERT_OFFSET ; do
    if [ "$__BOARD_DATA" == "$__BOARD" ]; then
      break
    fi
  done < <(echo "$__BOARD_DATA_LIST")
  if [ "$__BOARD_DATA" != "$__BOARD" ]; then
    write_log 13 "Error: Device $__BOARD is not supported"
  fi

  # Locate the correct partition
  local __PARTITION __PARTITION_NAME_CURRENT __PARTITION_NAME_PATH
  case "$__PARTITION_NAME" in
    /dev/mmc*)
      __PARTITION=$__PARTITION_NAME
      ;;
    *)
      # Search by mtd name
      for __PARITION_NAME_PATH in /sys/class/mtd/mtd*/name; do
        read -r __PARTITION_NAME_CURRENT < "$__PARITION_NAME_PATH"
        if [ "$__PARTITION_NAME" == "$__PARTITION_NAME_CURRENT" ]; then
          __PARTITION=${__PARITION_NAME_PATH%/name}
          __PARTITION=/dev/mtdblock${__PARTITION#/sys/class/mtd/mtd}
          break
        fi
      done
      ;;
  esac

  if [ -z "$__PARTITION" ] || [ ! -r "$__PARTITION" ]; then
    write_log 13 "Error: Could not find parition $__PARTITION_NAME"
  fi

  # Read the variables
  read -r       URL_USER      < <(dd if="$__PARTITION" bs=4k iflag=count_bytes,skip_bytes skip="$((__USER_OFFSET))"   count=6 | hexdump -e '6/1 "%02x"')
  read -r -d '' URL_PASS      < <(dd if="$__PARTITION" bs=4k iflag=count_bytes,skip_bytes skip="$((__PASS_OFFSET))"   count=16)
  read -r -d '' GLDDNS_DOMAIN < <(dd if="$__PARTITION" bs=4k iflag=count_bytes,skip_bytes skip="$((__DOMAIN_OFFSET))" count=16)
  if [ "$__CERT_OFFSET" != "_" ]; then
    read -r -d '' GLDDNS_CERT < <(dd if="$__PARTITION" bs=4k iflag=count_bytes,skip_bytes skip="$((__CERT_OFFSET))"   count=4096)
  fi
fi

[ -z "$URL_USER" ] && write_log 13 "Error: could not read user name (mac address)"
[ -z "$URL_PASS" ] && write_log 13 "Error: could not read password (serial number)"
[ -z "$GLDDNS_DOMAIN" ] && write_log 13 "Error: could not read DDNS domain"
[ -z "$CURL" ] && write_log 13 "Error: curl is required"
[ -z "$CURL_SSL" ] && write_log 13 "cURL: libcurl compiled without https support"

# Determine curl arguments, copied from dynamic_dns_functions.sh
local __PROG="$CURL -RsS -o $DATFILE --stderr $ERRFILE --user ${URL_USER}:${URL_PASS}"

# force network/interface-device to use for communication
if [ -n "$bind_network" ]; then
  local __DEVICE
  network_get_device __DEVICE "$bind_network" || \
    write_log 13 "Can not detect local device using 'network_get_device $bind_network' - Error: '$?'"
  write_log 7 "Force communication via device '$__DEVICE'"
  __PROG="$__PROG --interface $__DEVICE"
fi
if [ "${force_ipversion:-0}" -eq 1 ]; then
  [ "${use_ipv6:-}" -eq 0 ] && __PROG="$__PROG -4" || __PROG="$__PROG -6"	# force IPv4/IPv6
fi
# disable proxy if no set (there might be .wgetrc or .curlrc or wrong environment set)
# or check if libcurl compiled with proxy support
if [ -z "$proxy" ]; then
  __PROG="$__PROG --noproxy '*'"
elif [ -z "$CURL_PROXY" ]; then
  # if libcurl has no proxy support and proxy should be used then force ERROR
  write_log 13 "cURL: libcurl compiled without Proxy support"
fi

local __ERR __URL="https://ddns.glddns.com/nic/update?hostname=$GLDDNS_DOMAIN&myip=$__IP"
local __RUNPROG="$__PROG '$__URL' 2>$ERRFILE"
local __CNT=0

while : ; do
  case "$GLDDNS_CERT" in
    *"-----BEGIN PRIVATE KEY-----"*)
      local __KEY="-----BEGIN PRIVATE KEY-----${GLDDNS_CERT##*-----BEGIN PRIVATE KEY-----}"
      local __CERT="${GLDDNS_CERT%%-----BEGIN PRIVATE KEY-----*}"

      write_log 7 "#> $__RUNPROG --cert ... --key ..."
      eval "$__RUNPROG" --cert <(echo "$__CERT") --key <(echo "$__KEY")
      __ERR=$?
      ;;
    *)
      write_log 7 "#> $__RUNPROG"
      eval "$__RUNPROG"
      __ERR=$?
      ;;
  esac

  if [ $__ERR -eq 0 ]; then
    write_log 7 "DDNS Provider answered:${N}$(cat "$DATFILE")"
    if grep -q -s -E "^ok$" "$DATFILE"; then
      return 0
    fi
    return 1
  fi

  [ -n "$LUCI_HELPER" ] && return 1	# no retry if called by LuCI helper script
  write_log 3 "$__PROG Error: '$__ERR'"
  write_log 7 "$(cat "$ERRFILE")"

  if [ "${VERBOSE:0}" -gt 1 ]; then
    # VERBOSE > 1 then NO retry
    write_log 4 "Transfer failed - Verbose Mode: $VERBOSE - NO retry on error"
    return 1
  fi

  __CNT=$((__CNT + 1))
  if [ "${retry_max_count:-0}" -gt 0 ] && [ $__CNT -gt "$retry_max_count" ]; then
    write_log 14 "Transfer failed after $retry_max_count retries"
  fi
  write_log 4 "Transfer failed - retry $__CNT/$retry_max_count in $RETRY_SECONDS seconds"
  sleep "$RETRY_SECONDS" &
  PID_SLEEP=$!
  wait $PID_SLEEP	# enable trap-handler
  PID_SLEEP=0
done
