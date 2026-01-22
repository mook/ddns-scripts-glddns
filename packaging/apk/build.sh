#!/bin/sh

set -o errexit -o xtrace

if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct 2>/dev/null || date --utc +%s)
fi

get_field() {
  awk -F: "(\$1 == \"$1\") { \$1 = \"\" ; print }" control | sed 's@^ \+@@'
}

install -Dm0755 -t buildroot/usr/lib/ddns/ update_glddns_com.sh
install -Dm0644 -t buildroot/usr/share/ddns/custom/ glddns.com.json
files=$(find buildroot -type f -print)
install -d buildroot/lib/apk/packages/
echo "$files" > "buildroot/lib/apk/packages/$(get_field Package).list"

apk mkpkg \
  --info "name:$(get_field Package)" \
  --info "version:$(get_field Version)" \
  --info "description:$(get_field Description)" \
  --info "license:$(get_field License)" \
  --info "depends:$(get_field Depends | tr -d ,)" \
  --info "provides:$(get_field Provides | tr -d ,)" \
  --info arch:noarch \
  --files buildroot \
  --script post-install:post-install \
  --script pre-deinstall:pre-deinstall \
  --script post-upgrade:post-upgrade \
  --output /glddns.apk
