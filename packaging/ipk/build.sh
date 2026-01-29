#!/bin/sh

set -o errexit -o xtrace

if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct 2>/dev/null || date --utc +%s)
fi

: ${GIT_TAG:=$(git describe --always 2>/dev/null || echo '0.0.0')}

cat >control/control <<EOF
Package: ddns-scripts-glddns
Version: ${GIT_TAG#v}
Depends: curl, libc, ddns-scripts
Provides: ddns-scripts_glddns_com
Source: feeds/packages/net/ddns-scripts
SourceName: ddns-scripts
License: GPL-2.0
Section: net
SourceDateEpoch: ${SOURCE_DATE_EPOCH}
Architecture: all
Installed-Size: 10240
Description:  Dynamic DNS Client scripts extension for 'glddns.com'; requires supported GL.iNet router.
EOF

chmod a+x data/usr/lib/ddns/update_glddns_com.sh

compress() { #$1=dir
  (
    cd "$1"
    tar czf "../${1}.tar.gz" --mtime=@${SOURCE_DATE_EPOCH} --format=ustar .
  )
}
compress control
compress data
tar czf /glddns.ipk --format ustar debian-binary control.tar.gz data.tar.gz
