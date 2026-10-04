#!/bin/bash
# One-off: generates the replacement upload keystore for the Play Console
# upload-key reset (original prosme-upload-key.jks was lost). Writes the
# password straight into android/key.properties without ever printing it.
set -euo pipefail
cd "$(dirname "$0")/.."

KT="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot/bin/keytool"
KEYSTORE="android/prosme-upload-key-2026.jks"
ALIAS="prosme_upload_2026"
PROPS="android/key.properties"

NEWPASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)

"$KT" -genkeypair \
  -keystore "$KEYSTORE" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$ALIAS" \
  -storetype PKCS12 \
  -storepass "$NEWPASS" -keypass "$NEWPASS" \
  -dname "CN=Blumebyte, OU=ProSME, O=BLUMEBYTE, L=ACCRA, ST=Greater Accra, C=GH" \
  >/dev/null 2>&1

cat > "$PROPS" <<PROPSEOF
storePassword=$NEWPASS
keyPassword=$NEWPASS
keyAlias=$ALIAS
storeFile=../$KEYSTORE
PROPSEOF

"$KT" -exportcert -rfc \
  -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$NEWPASS" \
  -file android/upload_certificate_2026.pem >/dev/null 2>&1

echo "done: keystore + key.properties written, no password printed"
