#!/bin/sh
#
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Directories
TMP_DIR="/tmp/wazuh-indexer/certs"
CERTS_DIR="/etc/wazuh-indexer/certs"

# Create directories
mkdir -p "$TMP_DIR"

# If demo certificates are explicitly solicited
# (ie. for dockerized cluster test environments)
# then, use hardcoded certs.
if [ "${USE_DEMO_CERTS:-false}" = "true" ]; then
  cat <<'ADMIN_KEY' >$TMP_DIR/admin-key.pem
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC3ebYoJC7NR6YU
aYDnhRlawrb6BD4Oj3VkLsk4hIEKLo0afcexZWhW2iKqK1d7KLQir7ZqmodyQpzR
0/EbnwBEQXsWqxcACdestzADpLiX7J+RWKrLuQ1+wSOAAI/Y0pIEdrf9/5Jnj78o
I9xDEQxGlQjiJgvwJCkJXv4UD5LAXoKRnP1FRLWJxvCsLBKWuceNCVYu0QUPLkA7
XkshDSDYvsxD8G7hE/o7lKm9GjHduBDTmZ3dvcOzMtbxsGk5qMtHvXWgTK1YUkz4
f34m6E1ESLvxYveDzmcLMu4JJZEPIYWBUZV7ufeiDWhhXtT4vHoh6iLZdq4olIx3
fPsA8kEdAgMBAAECggEAOrEMFL4yXIeJeKkhS653pGF6T/MweM7qYhBXXSWB8+Rd
TfajfTtvy6y+/wmbU/H64cesxmBFaMcnTDYMwGW2G5+IxQEY+/GqFP2Ktfeo9yyC
BOhExqOdTglxlj5XxafiftwNUorBZjCFGU2TZb7b2u5M5679DaY7nFxPUdKDgtaO
IXRr7LYO2hQs57/e64UZvac994nwZBW17TWSmERGVGQs7fdSaPGwloA6phiyQflD
EmYxzMUFetpAu5Bk35hqLolw6htirkHzd8f0tFf3JvO1xvcZeVw1JDM/pV6Cfd9e
LZ8rabcwNYTuTFA/2bISSkReTvGebMJnIfl7g7nBTwKBgQDeQZr7MBww9n5LYdGS
B9z7DuAGZUWGIDqWPZT6pBNCbBhcQdrBEjSTUY/YQL1ofM/i/7A4xey5LZUZelUy
IgNSqpCC4McEkx565KcN3uNxXyJzwFsD4PhBkyQC5fYsjU9kGLKfv0MKy95ky9Y3
pbu7eegNEBvr1l9h/rtyRfchnwKBgQDTVNGBzaAxMjYN7z40+oo2Oc3B4OGqGXON
Ci5BABajFqvtudpUDAl06v95X1tY9f4EnpBtqNmnKu796aN8yycD+VTWIXttzqPX
uOqSgWQOkO/vAWcxbMHhyjv92wvJZAV0BeuaQgv+SKey3yqGn9rDIjV/xOX6yW1L
rmwl4ow7wwKBgD81620LNslaIXsw+9iLcfbZOS+4d7h4zBDUvN038t5OPfNnK18D
3X4UkVOQvg3MiZdm3uiWqgfUhfY0C6zxbX6CUg1W/mM3sFCFXVmdjZQ92V+QUpJc
1l5YCcLlQklTe0Pdnle+nsOgTcTfEDLNaQId3rhwX3CIjKIjP451hZ7DAoGBAL/m
WmSrSxbBSJJ4uB01kIHTFYNDaMekWugs4XmG0geAU9kIFjiRwZiYuCoHrBRpNCQP
tIjPde01sFWDbkCo3SHfq+jR+JnqtZ7zPJaSxj/v3uBCfulDn/8fPEC1Qsu6drU3
lwy5gtiCMz3bJmufBvCAxOHj8w47EHNTzMLOKJcvAoGAOrMBDVn4e4OPc138sef5
R+sgl2DWtKGUFFBYwT9oUFu2Jq6+ARSXg+gi9LBKfswWcJtiWyeDd54tyNdH+GBD
Oc76auI2UkXUJ99XCOzo1z85cBi9cIB14vdGAhLCrGXIJRx1VTlEcHtVOpWwbkfM
V4hJcul3lbTnrbuRHvVEOGk=
-----END PRIVATE KEY-----
ADMIN_KEY

  cat <<'ADMIN_CERT' >$TMP_DIR/admin.pem
-----BEGIN CERTIFICATE-----
MIIDDjCCAfYCFD71oGZblxldV2/96zP2kZpIKOYgMA0GCSqGSIb3DQEBCwUAMDUx
DjAMBgNVBAsMBVdhenVoMQ4wDAYDVQQKDAVXYXp1aDETMBEGA1UEBwwKQ2FsaWZv
cm5pYTAeFw0yNDExMjAxNjUxMDRaFw0zNDExMTgxNjUxMDRaMFIxCzAJBgNVBAYT
AlVTMRMwEQYDVQQHDApDYWxpZm9ybmlhMQ4wDAYDVQQKDAVXYXp1aDEOMAwGA1UE
CwwFV2F6dWgxDjAMBgNVBAMMBWFkbWluMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAt3m2KCQuzUemFGmA54UZWsK2+gQ+Do91ZC7JOISBCi6NGn3HsWVo
VtoiqitXeyi0Iq+2apqHckKc0dPxG58AREF7FqsXAAnXrLcwA6S4l+yfkViqy7kN
fsEjgACP2NKSBHa3/f+SZ4+/KCPcQxEMRpUI4iYL8CQpCV7+FA+SwF6CkZz9RUS1
icbwrCwSlrnHjQlWLtEFDy5AO15LIQ0g2L7MQ/Bu4RP6O5SpvRox3bgQ05md3b3D
szLW8bBpOajLR711oEytWFJM+H9+JuhNREi78WL3g85nCzLuCSWRDyGFgVGVe7n3
og1oYV7U+Lx6Ieoi2XauKJSMd3z7APJBHQIDAQABMA0GCSqGSIb3DQEBCwUAA4IB
AQCOYHh3KgCfVyJdt9xMqGmb/GNeitxt8dZtatEiwE29O2ABUK3i24SYAb/fGZ1F
eSc184njF/9rD8SCNEo8rfD6HjP6EsdoPFtekvEC1Ykrxk1chvpC1EHNZPGWZ6Wk
UKuEORYyv4rzngvT9K/77iw8clW225uGp1GtcNgw45LnIdCEGf+Uy8uKOkzKs7Uf
Mnl2zHy0S6gYV5aBWDW9WuuUQnoVTNdnAs6e4UGIw5T/l5W7WKDG9Q+F+Xrt4Cvx
W8evS+3vVVF+EYwBXBQRZhkL7f+sJnizhdzCUMqztGZR1rsjl+Vz+S6u77KrKIop
BzcZ+J6GzTHIZXHI77PvXHtf
-----END CERTIFICATE-----
ADMIN_CERT

  cat <<'INDEXER_KEY' >$TMP_DIR/indexer-key.pem
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDJZsCQdRwFIszQ
XtccbLLs3aUquhbIdGwpDALXtOa8XWBRhusSLgftmNfIQg4adPVgqzXvij546wiQ
mVOsmyLht1C5UwoKzsDfQYrbyzrw8dGYmCDnrBPbB///XskQeChIygRHgfrqZM6E
l1BbL2FZ8SvdoKSemRgQ7YaVh94ZF9H4u9IDDldKX5kYEia2tMV9lrv7gbtLBhK0
6Ec2mFL/cKp6fFFynaPgWg+5AfbCygVitAt2OG9kNLbI6cZ/MvrkWrnIciWluwna
mmf9RJaHBNIvcu6Wf1gtaDMyPf8Non/35B3uccYh0dkonIrcpeiWmBtoY0K6+2AV
ottNt4wXAgMBAAECggEAFgHoYOCrIyneVOvyzY8DLjw6Ds/ZgCYDUP5DAUHUmhi0
rF6gfpK7wwwZ6C7E+RchXmLXDfR+nG/yYPqgLhL1s3x4kbJakpEXz6LgguFTm33m
d/+Ho557Z5/EKtTiBlla7Y6a+8Ve9GX3kH2IW65zENpNqiDNBuzruE3RkF1nDjle
L/ShZp/MaLdUDRGucRfSg/QtulEk1swjsakB7gA+UVbi0N3bAYDIjC/0sQkD9AW/
Z7c98oiA6V7vIaUynVYNO1u7jfKMTskYZdMT9BqYxduvHKf3q9vHQWx5z+OTclb6
I5tZljoe6ksd0R0TLHJMVMjP4xf8dAEvcmqXB6y+wQKBgQDLFNkG4LrnJJDaMSjt
gfEnyxXUv0ZIjZq0Om/0mNZeNddfjLeGeQ1LDsUFnyzKKUKWLhgaQcvaUHuQt9zU
dGICNj9ivsY0BZq7zN5th0MIKwYaWjYH0jdmQeWU8U7nUp20vtYxaCRB8WAi1Pmh
fXAe3e49iL5AJD8la4V+wibf6QKBgQD94dS7Yle29QJ7EBPyhHjANqxP6QEvocmO
40G3FBNmyhR/OW8ldn9CADoExlxcIXOsr8WiyGEFHULs8fZX/7wM+2HffFJ+kOtI
5Z7XE4mmvyqIolGTXK428PQVlvbitUKYm3lET9WBvlxa5m54vJPlNU9gqlBUF/CV
SW2fYjOL/wKBgHmthReE4ReLJitFlzMvTzG7kdoFvPPNvGrONLRGOvL5qZC7fF7a
+ucE83GZ3LlIHXhkJ9bbo2usG00rjOnSzcJrhHECwzj6PqrVZlQT3krvlFmHwaXQ
A5eGVit2pgMd0hYw3Z9+uXK1UBeuqd9jjCFCcfN2kh9WWGtwT+0SIT65AoGAFVpR
EhGLXw/sTX1ksBkELuZqR65JM0BgO2xRspw1pYeJgcnK11PIED0EpDIqwnTtzbBa
5v4DavKzFkqjdXNE1bKu4KUMKyj1IQRu/5fdE/EwGp3MTqCU5noNjWNNEHQ+TaeF
44DzbB4elmabE/yIU9bP/klUyD3bNjMezTDtNPECgYEAk9Ffhaw0Y/xgofCmvLRI
79SbEbPSTXG4ICCAjEm/7oE8/BDEg8sV4fFSWFrUSfroQHX/AogRB9aAOPwoVwsd
vkfzHxhsATJGZftq1XvdRpoHGYpZXO8FZ9BlFLeS7Y156RgLl6rAtoG6EWQwzoB2
KhyfqIhMJFSEqFwz8nsLcDo=
-----END PRIVATE KEY-----
INDEXER_KEY

  cat <<'INDEXER_CERT' >$TMP_DIR/indexer.pem
-----BEGIN CERTIFICATE-----
MIIDrTCCApWgAwIBAgIUXrjOPxnJtoICOqL+z9QzqccrhE0wDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTEyMDE2NTEwNVoXDTM0MTExODE2NTEwNVowYTELMAkG
A1UEBhMCVVMxEzARBgNVBAcMCkNhbGlmb3JuaWExDjAMBgNVBAoMBVdhenVoMQ4w
DAYDVQQLDAVXYXp1aDEdMBsGA1UEAwwUbm9kZS0wLndhenVoLmluZGV4ZXIwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDJZsCQdRwFIszQXtccbLLs3aUq
uhbIdGwpDALXtOa8XWBRhusSLgftmNfIQg4adPVgqzXvij546wiQmVOsmyLht1C5
UwoKzsDfQYrbyzrw8dGYmCDnrBPbB///XskQeChIygRHgfrqZM6El1BbL2FZ8Svd
oKSemRgQ7YaVh94ZF9H4u9IDDldKX5kYEia2tMV9lrv7gbtLBhK06Ec2mFL/cKp6
fFFynaPgWg+5AfbCygVitAt2OG9kNLbI6cZ/MvrkWrnIciWluwnammf9RJaHBNIv
cu6Wf1gtaDMyPf8Non/35B3uccYh0dkonIrcpeiWmBtoY0K6+2AVottNt4wXAgMB
AAGjgYgwgYUwQwYDVR0RBDwwOoIJbG9jYWxob3N0gg8qLndhenVoLmluZGV4ZXKI
BCoDBAWHBH8AAAGHEAAAAAAAAAAAAAAAAAAAAAEwHQYDVR0OBBYEFMAV32UwZfmX
Mdi7/yQgHIGLc1GNMB8GA1UdIwQYMBaAFLiKwlbLzv/mfFaa/vd8PmlIFEl4MA0G
CSqGSIb3DQEBCwUAA4IBAQAFH8WX5+WEFICfLeHL8QDeMefkyVgNAl1jo8OPKKbA
fhmHin54DWrfSC3V3Xeo1olj53N/2G5dsfUWJ1fb7rnrkwqSV3yVak8z4lWPRfgW
pBf48rwt2UCvAIzZZawyU74jKjcA938ZIm9jz1mFSgvfLVPWz0d6ENt/9VFHJHq2
yNaP/ymON5Z7bCXbpztr73cUYQmDzIH9Kj/tzxaYhomR2U/Zk92Ow+ZEtH7866CQ
51ombiWxQB2MqfZbZH0BcfaeFqiu6DF0b26xbqqH/8qcNtljc/I5u3EbXny7n0Pi
mVGWK9t6LlKwb/u1zTKn+Ayy24fzELpG/y5CF35BW+Zy
-----END CERTIFICATE-----
INDEXER_CERT

  cat <<'ROOT_CA' >$TMP_DIR/root-ca.pem
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIUI7nMX6wJ4fcTo1JfSUNtuFNlgNIwDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTEyMDE2NTEwNFoXDTM0MTExODE2NTEwNFowNTEOMAwG
A1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApDYWxpZm9ybmlh
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqbtN6t/RHs29r9qg4759
2R71qRmSaPU+MW3oZA4XzqTa9p/BCcmmemLIUalp+WeUCBlUB34eMEpA9vZ7cT0j
UQQNnTCx/6iWY95qAl8dIQUZeuYM6FmIMuZhzmIgdamMHh9YKYctuBBNJ2ySwnwe
G4lON+1wvBipMGM5OjXkhnYhg2lz9EfjjBdBgpAMjBgULZ2vKc8u+xX9ILk0v507
wDO4sLkXzes63wX/I98R1XJ8ttqLjUvVxxDkeFZmoNa9t2nZkweQrwYJc/NiF1u9
VqIFYJM/3MAfYR/pAaB/ma+0Aq81JkEmh0wj6HayRtIrU36SFoGP/xdip6RhGSbJ
AQIDAQABo1MwUTAdBgNVHQ4EFgQUuIrCVsvO/+Z8Vpr+93w+aUgUSXgwHwYDVR0j
BBgwFoAUuIrCVsvO/+Z8Vpr+93w+aUgUSXgwDwYDVR0TAQH/BAUwAwEB/zANBgkq
hkiG9w0BAQsFAAOCAQEAor0/yTsFn1/sd+CkcqpBharEX1Xq1FRVDN1DJYXJ/eUS
cl+Yyg72fe+cbwOHMbwhiJxWhX1nlWby6RO+vbNADXy+GCxNnpNnVe3maYk3DA2q
G5VNJtXv7OYjdIP5/4rOmbhTPoZfmsmKRGCMJEtJ0uq+VLrtPJsH10nAp8vceoMc
PQB0He59izGVDwH47iJKVJVb7AnMFALFzlSYdjA0gVSXwj4n+VnVK2inBRwQ3MFl
u2MM6NS9vE8IgX4+3X7cJkg2i6dLxGX69vTDyh6Y2obh4FgcY1PQfsUVZcWlSVvf
kV0DupKzxHxUDXX8TvzihxGEkEi8HIYOQes7pTNTiw==
-----END CERTIFICATE-----
ROOT_CA

# Otherwise, default to randomized certs generation
else
  # Root CA
  openssl genrsa -out "$TMP_DIR/root-ca-key-temp.pem" 2048
  openssl req -new -x509 -sha256 -key "$TMP_DIR/root-ca-key-temp.pem" -subj "/OU=Wazuh/O=Wazuh/L=California/" -out "$TMP_DIR/root-ca.pem" -days 3650

  # Admin cert
  openssl genrsa -out "$TMP_DIR/admin-key-temp.pem" 2048
  openssl pkcs8 -inform PEM -outform PEM -in "$TMP_DIR/admin-key-temp.pem" -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "$TMP_DIR/admin-key.pem"
  openssl req -new -key "$TMP_DIR/admin-key.pem" -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=admin" -out "$TMP_DIR/admin.csr"
  openssl x509 -req -in "$TMP_DIR/admin.csr" -CA "$TMP_DIR/root-ca.pem" -CAkey "$TMP_DIR/root-ca-key-temp.pem" -CAcreateserial -sha256 -out "$TMP_DIR/admin.pem" -days 3650

  # Node cert
  openssl genrsa -out "$TMP_DIR/indexer-key-temp.pem" 2048
  openssl pkcs8 -inform PEM -outform PEM -in "$TMP_DIR/indexer-key-temp.pem" -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "$TMP_DIR/indexer-key.pem"
  openssl req -new -key "$TMP_DIR/indexer-key.pem" -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=node-0.wazuh.indexer" -out "$TMP_DIR/indexer.csr"
  cat <<'INDEXER_EXT' >$TMP_DIR/indexer.ext
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = *.wazuh.indexer
RID.1 = 1.2.3.4.5
IP.1 = 127.0.0.1
IP.2 =  0:0:0:0:0:0:0:1
INDEXER_EXT

  openssl x509 -req -in "$TMP_DIR/indexer.csr" -CA "$TMP_DIR/root-ca.pem" -CAkey "$TMP_DIR/root-ca-key-temp.pem" -CAcreateserial -sha256 -out "$TMP_DIR/indexer.pem" -days 3650 -extfile "$TMP_DIR/indexer.ext"

  # Cleanup temporary files
  rm "$TMP_DIR/"*.csr "$TMP_DIR"/*.ext "$TMP_DIR"/*.srl "$TMP_DIR"/*-temp.pem
fi

# Move certs to permanent location
mkdir -p "$CERTS_DIR"
mv "$TMP_DIR"/* "$CERTS_DIR/"

chmod 500 "$CERTS_DIR"
chmod 400 "$CERTS_DIR"/*
chown -R wazuh-indexer:wazuh-indexer "$CERTS_DIR"

# Cleanup /tmp directory
rm -r "$TMP_DIR"
