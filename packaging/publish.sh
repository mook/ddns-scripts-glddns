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

set -o errexit -o nounset

GNUPGHOME=$(mktemp -d)
trap "rm -rf $GNUPGHOME" EXIT

mkdir out

APK=${APK:-$(echo *.apk)}
IPK=${IPK:-$(echo *.ipk)}

tar xf "$IPK" --to-stdout control.tar.gz | tar xz --to-stdout ./control > out/Packages
gzip -k out/Packages

get_field() {
  awk -F: "(\$1 == \"$1\") { \$1 = \"\" ; print }" out/Packages | sed 's@^ \+@@'
}

NAME=$(get_field Package)
VERSION=$(get_field Version)
ARCHITECTURE=$(get_field Architecture)

cp "$IPK" "out/${NAME}_${VERSION}_${ARCHITECTURE}.ipk"
cp "$APK" "out/${NAME}-${VERSION}.apk"

gpg --import "$KEYFILE"
gpg --detach-sign --armor out/Packages
apk mkndx --allow-untrusted --output out/packages.adb "$APK"
gpg --detach-sign --armor out/packages.adb
