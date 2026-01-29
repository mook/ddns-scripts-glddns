#!/bin/sh

# This script handles publishing the release to the repository.
#
# Required inputs (environment variables):
#
#   KEYFILE  Path to GPG key key for signing
#
# The apk and ipk files also must exist in the current directory.
#
# The repository structure will be written to a new "out" directory in the
# working directory.

# shellcheck shell=busybox enable=all


set -o errexit -o nounset -o pipefail

: "${KEYFILE:?}"
APK=${APK:-$(readlink -f ./*.apk)}
IPK=${IPK:-$(readlink -f ./*.ipk)}

mkdir out
OUT_DIR=$(cd out && pwd)

WORK_DIR=$(mktemp -d)
# shellcheck disable=2064 # Expand immediately, run the trap command later.
trap "rm -rf '${WORK_DIR}'" EXIT
cd "${WORK_DIR}"

tar xf "${IPK}" --to-stdout control.tar.gz | tar xz --to-stdout ./control > "${OUT_DIR}/Packages"

get_field() {
  awk -F: "(\$1 == \"$1\") { \$1 = \"\" ; print }" "${OUT_DIR}/Packages" | sed 's@^ \+@@'
}

NAME=$(get_field Package)
VERSION=$(get_field Version)
ARCHITECTURE=$(get_field Architecture)

sq() {
  command sq --key-store="${WORK_DIR}/keystore" "$@"
}

cp "${IPK}" "${OUT_DIR}/${NAME}_${VERSION}_${ARCHITECTURE}.ipk"
cp "${APK}" "${OUT_DIR}/${NAME}-${VERSION}.apk"

cat >>"${OUT_DIR}/Packages" <<EOF
Filename: ${NAME}_${VERSION}_${ARCHITECTURE}.ipk
Size: $(stat -c %s "${IPK}")
SHA256sum: $(sha256sum "${IPK}" | cut -d ' ' -f 1)
EOF
gzip -k "${OUT_DIR}/Packages"

sq key import --quiet "${KEYFILE}"
keyid=$(basename "${WORK_DIR}/keystore/softkeys/"*.pgp .pgp)
sq sign --signature-file "${OUT_DIR}/Packages.asc" --signer "${keyid}" "${OUT_DIR}/Packages"
apk mkndx --allow-untrusted --output "${OUT_DIR}/packages.adb" "${APK}"
sq sign --signature-file "${OUT_DIR}/packages.adb.asc" --signer "${keyid}" "${OUT_DIR}/packages.adb"

# Sign with OpenWRT usign.  This is somewhat confusing because we convert the
# GPG key for use with usign.
sq packet split --output-prefix=key-parts "${KEYFILE}"

dump_key() { # <Heading>
  sq packet dump --mpis key-parts-*-Secret-Key-* \
    | awk "
        BEGIN { p = 0 }
        /${1}/ { p = 1 }
        /^\s+\d{8,}/ { if (p) { \$1 = \$1 \":\" ; print } }
      " \
    | { xxd -r 2>/dev/null || true ; } \
    | xxd -p -c9999
}

# secret and public keys, as hexdumps
secret=$(dump_key "Secret Key:")
public=$(dump_key "Public Key:" | tail -c+3)
salt=$(head -c16 /dev/urandom | xxd -p -c9999)
fingerprint=$(head -c8 /dev/urandom | xxd -p -c9999)
checksum=$(echo "${secret}${public}" | xxd -r -p | sha512sum -b | head -c16)

echo "untrusted comment: private key ${fingerprint}" > usign.key
sed 's@#.*@@' <<EOF | xxd -r -p | base64 -w0 >> usign.key
45 64 42 4B 00 00 00 00 # pkalg="Ed" kdfalg="BK" kdfrounds=(uint32)0
${salt}
${checksum}
${fingerprint}
${secret}
${public}
EOF

echo "untrusted comment: public key ${fingerprint}" > usign.pub
sed 's@#.*@@' <<EOF | xxd -r -p | base64 -w0 >> usign.pub
45 64 # pkalg="Ed"
${fingerprint}
${public}
EOF
echo >> usign.pub

cat >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}" <<"EOF"
## OpenWRT signing key:
```
EOF
cat usign.pub
echo '```' >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"

usign -S -m "${OUT_DIR}/Packages" -s usign.key
usign -V -m "${OUT_DIR}/Packages" -p usign.pub
