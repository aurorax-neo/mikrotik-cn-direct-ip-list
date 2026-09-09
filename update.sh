#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUTPUT_DIR="$SCRIPT_DIR"
SOURCE_URL="${SOURCE_URL:-https://cdn.jsdelivr.net/gh/appshubcc/bett-rules@meta/geo/geoip/cn.list}"
PROXY_URL="${PROXY_URL:-}"

usage() {
    cat <<'EOF'
Usage: ./update.sh [options]

Options:
  --proxy URL    Proxy URL for curl, e.g. http://127.0.0.1:7890
                 Also supports socks5h://, https://, and other curl proxy schemes.
  --source URL   Override the upstream CIDR list URL.
  -h, --help     Show this help.

Environment:
  PROXY_URL      Same as --proxy.
  SOURCE_URL     Same as --source.

Examples:
  ./update.sh --proxy http://127.0.0.1:7890
  PROXY_URL=socks5h://127.0.0.1:7890 ./update.sh
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --proxy)
            [ "$#" -ge 2 ] || { echo "--proxy requires a URL" >&2; exit 2; }
            PROXY_URL=$2
            shift 2
            ;;
        --source)
            [ "$#" -ge 2 ] || { echo "--source requires a URL" >&2; exit 2; }
            SOURCE_URL=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/mikrotik-cn-direct.XXXXXX")
cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

curl_args=(
    --fail --silent --show-error --location
    --retry 5 --retry-delay 2
    --connect-timeout 15 --max-time 180
    --output "$work_dir/cn-source.list"
)
if [ -n "$PROXY_URL" ]; then
    curl_args+=(--proxy "$PROXY_URL")
    echo "Downloading through proxy: $PROXY_URL"
else
    echo "Downloading without an explicit proxy"
fi

echo "Source: $SOURCE_URL"
curl "${curl_args[@]}" "$SOURCE_URL"

python3 - "$work_dir/cn-source.list" "$work_dir" <<'PY'
from pathlib import Path
import ipaddress
import sys

source = Path(sys.argv[1])
out = Path(sys.argv[2])

nets = []
for line_no, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
    value = line.strip()
    if not value or value.startswith("#"):
        continue
    try:
        nets.append(ipaddress.ip_network(value, strict=True))
    except ValueError as exc:
        raise SystemExit(f"Invalid CIDR at line {line_no}: {value}: {exc}")

nets = sorted(set(nets), key=lambda network: (
    network.version, int(network.network_address), network.prefixlen
))
v4 = [network for network in nets if network.version == 4]
v6 = [network for network in nets if network.version == 6]

(out / "cn-ipv4.txt").write_text("\n".join(map(str, v4)) + "\n", encoding="ascii")
(out / "cn-ipv6.txt").write_text("\n".join(map(str, v6)) + "\n", encoding="ascii")

def header(counts):
    return [
        "# China mainland direct IP address list for MikroTik RouterOS",
        "# Source: https://github.com/appshubcc/bett-rules",
        "# Upstream file: meta/geo/geoip/cn.list",
        f"# {counts}",
        "# Address-list name: CN-DIRECT",
        "# Import with: /import file-name=<this-file>.rsc",
        "",
    ]

def address_lines(networks):
    return [f'add list="CN-DIRECT" address={network}' for network in networks]

ipv4_lines = (
    header(f"IPv4 prefixes: {len(v4)}")
    + ["/ip firewall address-list", 'remove [find where list="CN-DIRECT"]']
    + address_lines(v4)
)
(out / "mikrotik-cn-direct-ipv4.rsc").write_text(
    "\n".join(ipv4_lines) + "\n", encoding="ascii"
)

ipv6_lines = (
    header(f"IPv6 prefixes: {len(v6)}")
    + ["/ipv6 firewall address-list", 'remove [find where list="CN-DIRECT"]']
    + address_lines(v6)
)
(out / "mikrotik-cn-direct-ipv6.rsc").write_text(
    "\n".join(ipv6_lines) + "\n", encoding="ascii"
)

all_lines = (
    header(f"IPv4 prefixes: {len(v4)}; IPv6 prefixes: {len(v6)}")
    + ["/ip firewall address-list", 'remove [find where list="CN-DIRECT"]']
    + address_lines(v4)
    + ["", "/ipv6 firewall address-list", 'remove [find where list="CN-DIRECT"]']
    + address_lines(v6)
)
(out / "mikrotik-cn-direct-ipv4-ipv6.rsc").write_text(
    "\n".join(all_lines) + "\n", encoding="ascii"
)
(out / "mikrotik-cn-direct-all.rsc").write_text(
    "\n".join(all_lines) + "\n", encoding="ascii"
)

print(f"Generated IPv4={len(v4)} IPv6={len(v6)} total={len(nets)}")
PY

for file in cn-source.list cn-ipv4.txt cn-ipv6.txt \
    mikrotik-cn-direct-ipv4.rsc mikrotik-cn-direct-ipv6.rsc \
    mikrotik-cn-direct-ipv4-ipv6.rsc mikrotik-cn-direct-all.rsc; do
    mv "$work_dir/$file" "$OUTPUT_DIR/$file"
done

echo "Updated files in: $OUTPUT_DIR"
