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
if [ $USE_DEMO_CERTS == "true" ]
then
cat <<'ADMIN_KEY' > $TMP_DIR/admin-key.pem
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC9EEeHfF8mDNMb
XjKZYm5HPND/bX6+xzs9K89ybavKiaCkjuoeSu9jdger7/L6VfO5+VKSvni5FNBt
fZ9Gv5knoOA8nGxgUK5NimJRzVbWLMXAFUDLdG8TTeWJj/uH72DQfPqev+oO7Ast
yJvSdB+veo6Thw1M72zgpdCj7OyGb45F9YLENZUb0alIAWNC2w96r5GGOt9ZN791
KIh9ynBlDKg0DFQuin60Qo9PiHQE2JN9x6Ipag4tXXBVsChbEcbg6BrTTZeq559E
SnWZLPtdOjJZXk2nG9chWr4KIhrrk+2omQAaMM7+4v0V5BUBiu8zW2HOiBGrj7T6
RlOxWouZAgMBAAECggEAAUR0q6HXzsd95XcSMRkJ0uHDfOgyVfu77UMNQZ/JQQhU
fVs/591qEWlJz+CXPmUJHJFhTlPcjKZpEfLU+IJxomRfschSqaqgyyrxpx67RaBI
ixXEDhkaYtoTfy0/QGqzDsgSXgdnUvDzejvCtPx2TJTZE9VvRLluKhYHz1wtPGbM
F0EFVjQupNpVOEwWLSF3m0zsGsYKDdM+/+CZjc2tLyMJiLJKgCv/4TpbS6t9/x0d
PfgDzuyMtKrkwHt6G7wwyv8EbbiBq9cnPdfZVffxwLD9h0zHaG6UmYDa2pyzr+pT
CE/2Gg5tYczpUKhYvhRn6w7DcZi5zNhpEuHampAuSQKBgQDnpIJOBLKBlDSj07uu
HZ8gkFqtoavg0V33wMj8jkPcEsbuFPDQy8LhHnqXu5jxIMT/cYuDEz44H3qPv2bo
DoFcn6JayVaNgOeQjNy0bQ1SJ5Oz7XKwg/pZCOcI3zmMAhAvuwUaPAKGSMSlQhGK
jMa1QF42daz8fn2h17uDWu8aYwKBgQDQ8Zp8ShYzK12oob0UYzVJwgLhvT1ShMMo
KrNmBPONPlTf9UFGIHLmSkfbNE1TiIciX2lQQ2nRddcsUDqIn+kQ/i2cpZWADlO5
czMvmnq5ixGVLAhWHnnZuZhnZW/1fxFeYe1kf3mV4jua5Ryy/ysr43EHZfcD8ead
EIVJS9zE0wKBgQCpjS6bsLCATFzjdX2wipoJGeBlqyrF2jnvuLrksbVWBqB5b/Z8
vkicwtR076mZBaVsXE4D2Tf3mIL7aNwIC2YAyA/sZ+bkmG/mzFRX9GKFudZRIwKJ
1XCPbwa85beXlYMHjNrFQxuN8wGM/Pkd8sEXtk+/iQ7fmi6XIfNsyEivhQKBgBZ+
7LMVBu7bbGoLf+ACDmqyiLzlMwT/ZkOc1VPWlKJQY7L5JN34AGbq+HGRYAHuYR5C
R4RsvaffmBsdSDANh3pc42xKJ55x7HG7BXfKmgv//RSieQNMpLHcWZxIP5We6K/Q
u05mqyCICwLSSBS9hFhlVHYHdGDoWnvum2sYz9whAoGAL4oUzh98hcRzdyYNKUd+
kLksS2xWtcyURa3qKXuM7fpHgn1+C0GneWRKOgLZEgXSEFnU5KCEkvppIoja9EeG
DbyIbrJdsM+otUvCtK7CElIIXxnWeUrQo3KdwNEKFWJBz++JVHuL5r3kBm42YLyU
HYSApfYjTQwaUKuQhE1XLeE=
-----END PRIVATE KEY-----
ADMIN_KEY

cat <<'ADMIN_CERT' > $TMP_DIR/admin.pem
-----BEGIN CERTIFICATE-----
MIIDDjCCAfYCFD9OlS056xZCoo1S/yJNVnh8PRmKMA0GCSqGSIb3DQEBCwUAMDUx
DjAMBgNVBAsMBVdhenVoMQ4wDAYDVQQKDAVXYXp1aDETMBEGA1UEBwwKQ2FsaWZv
cm5pYTAeFw0yNDExMTkwOTMyMzNaFw0zNDExMTcwOTMyMzNaMFIxCzAJBgNVBAYT
AlVTMRMwEQYDVQQHDApDYWxpZm9ybmlhMQ4wDAYDVQQKDAVXYXp1aDEOMAwGA1UE
CwwFV2F6dWgxDjAMBgNVBAMMBWFkbWluMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAvRBHh3xfJgzTG14ymWJuRzzQ/21+vsc7PSvPcm2ryomgpI7qHkrv
Y3YHq+/y+lXzuflSkr54uRTQbX2fRr+ZJ6DgPJxsYFCuTYpiUc1W1izFwBVAy3Rv
E03liY/7h+9g0Hz6nr/qDuwLLcib0nQfr3qOk4cNTO9s4KXQo+zshm+ORfWCxDWV
G9GpSAFjQtsPeq+RhjrfWTe/dSiIfcpwZQyoNAxULop+tEKPT4h0BNiTfceiKWoO
LV1wVbAoWxHG4Oga002XquefREp1mSz7XToyWV5NpxvXIVq+CiIa65PtqJkAGjDO
/uL9FeQVAYrvM1thzogRq4+0+kZTsVqLmQIDAQABMA0GCSqGSIb3DQEBCwUAA4IB
AQDUje7n/NdxBOf5yXct9lJ4nai0Mf6kuq1PLgNjYkqK0wTX90nGi0UlbkfI30w/
bBPsrOjQgQmNHPXn+IP96XEdvHlVln0AAReU66myHWo4YU295gy1C5Bu9bCyu71Y
xXxnNuT5Bt51i95ypcP+VH4ue5MXIughzgEDEJNCMWMPKsemEZMTmjiNiAcQq5Ww
rYg3BH2tKNd61jtMA2Xt72Lgm4baqlWZ3z57Dn8k+63iYuZspopu8QYoV+lWyOoT
NIMUY1VJspF0NOsxx42xfrez9J9J6SY0qrRKaIBdAXOcpAxg8xPJMvAzzCtC7M/F
/JH4ves/fV2ndBaOc3j4TtBa
-----END CERTIFICATE-----
ADMIN_CERT

cat <<'INDEXER_KEY' > $TMP_DIR/indexer-key.pem
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCTDJLziFY3IjhM
DW8sNcC598nCEosGeIxidKOCeG7PzVR/UIgULq/YyBm443nFW65qQJreuM1Rx9tS
4qnIWNS02MWDILy1/jmErafb0dzRQntd7IMf6Oh/3MSu0jaH903HvyepcRloIXNE
zx/nLp/F5f2fZbiVTamEqnQwk9rsGB+6mWzfT/B9713VRvpdPcKD5frYrrYRaq3y
NKywqFSyxuBoB5ZC+YaL678npImCTs6ukjYiybvxxqitshbkDtRjdiIZTjVMLC9+
WNZ89T9zyLkAPrrPW7yHRHvxokXneAoVsIufH5VmyBYBNJDf0sGtRGoT+07Vh/Eq
RazA6cavAgMBAAECggEAFCn1PKUarWoT2NnpagvfkaCuGd6mZwzAs1TV1wjh/mdk
NCZm192kX1A7trlP9AV5Co4xWQ5zmR3pWpmaOSQf3BdIKOL5qDsOyBLH9xdKoFHt
eMOlzLUIrKp+jeUQH9+EMDprcItXCzW1s18eO3qOjiSA0rVaykkL+xUkju9iEF2e
luHTq8G5RTi79BJaybiXu5R+VdHx8JdMoitwsKrazC/mZorkBiUBvlSEy7fvyh+s
a2zvQifqJmqGCws1AWuGLZgM+0fSKqoMyTWiYl3M/MhnRFHmOlddJ6r3Jvbeq2FM
g1RX2FvkHTRGwIy/xHfpm+t2ioi1ukDpp7GOFkB+gQKBgQDHLOHx8yY0ywcoa2jD
Ux8MYLpvMHnKxq2TLITjB17KuRHycfvbt+YWLDZeE3s6goyTLwOdK/FrzVLqThLn
FP8XAihO04ttrlqW7h7GF6ZjdomKR7vNar0YIom8BQEgaU7DFcBFs9TWwJukCWc0
zl9dmsihzXAmcyfZ6JL+f1rU+wKBgQC9AJAiQ9L9lwwHxiMSO41tF7sjv3GfGndL
4RuTYbQrlDeqoARwX132lXb/1mtfpwwv8Ho9Er9ZnAnzPPJKVyyxkuIcQV67PUy/
+NY4bc+PuS5a35mRbmlnzS1Wbkf0qNqoQRd0zp94MuysoH7NrRxj9ok739xupJQ+
NYc3YJee3QKBgQCWTZh0LTk3vb65EdUNETzs6lHGdp5yF1wFJCNj77vo36BbhQi6
1hwbv2GHvMvRa5MJvwDLKs4Uu+1GQ4SgPYgCpO4mDh25t0lFfIxckJxPkrRYVamz
akkoXWfzKxOekdmN/mwKLZsANHk/YJkxkEsHKDcfYxiu61e3aXsD8rdo4QKBgQC6
8W6fZcSxLhEpM1MHOr5VdI6W+kpxW+U5uYvkCFUEcdNpwmMBn2K6fvY4caa88ub8
F/lgpUV9Zfj1jYf9/iHn9mgOGJ6Rxz09+Owy3nLaLwlpuxcToUlC8c/xWJ11ovq8
R73ivGlBo+UzjoA+Agc93OG6xl8rVUCIE7wOC02NRQKBgEdEZPP+biM09s3sqc3k
qABIKvu65SwjKoYXMTkZoiAoU06qloIMqeYOvAERH/+ST2s2lI/FpSWDE18b3Gze
WSFbFoR3mUg1/iy5cBTlqlopZCL/og71LoxhMzgg6I0ga+TDheQe/Dsdvn42TAUp
r3zr1bwITB2wXNEs8Lz/MgE3
-----END PRIVATE KEY-----
INDEXER_KEY

cat <<'INDEXER_CERT' > $TMP_DIR/indexer.pem
-----BEGIN CERTIFICATE-----
MIIDazCCAlOgAwIBAgIUP06VLTnrFkKijVL/Ik1WeHw9GYswDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTExOTA5MzIzM1oXDTM0MTExNzA5MzIzM1owUzELMAkG
A1UEBhMCVVMxEzARBgNVBAcMCkNhbGlmb3JuaWExDjAMBgNVBAoMBVdhenVoMQ4w
DAYDVQQLDAVXYXp1aDEPMA0GA1UEAwwGbm9kZS0xMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAkwyS84hWNyI4TA1vLDXAuffJwhKLBniMYnSjgnhuz81U
f1CIFC6v2MgZuON5xVuuakCa3rjNUcfbUuKpyFjUtNjFgyC8tf45hK2n29Hc0UJ7
XeyDH+jof9zErtI2h/dNx78nqXEZaCFzRM8f5y6fxeX9n2W4lU2phKp0MJPa7Bgf
upls30/wfe9d1Ub6XT3Cg+X62K62EWqt8jSssKhUssbgaAeWQvmGi+u/J6SJgk7O
rpI2Ism78caorbIW5A7UY3YiGU41TCwvfljWfPU/c8i5AD66z1u8h0R78aJF53gK
FbCLnx+VZsgWATSQ39LBrURqE/tO1YfxKkWswOnGrwIDAQABo1UwUzARBgNVHREE
CjAIggZub2RlLTEwHQYDVR0OBBYEFK4MZGG1h6w7xlMlf2s7FBeLfhIcMB8GA1Ud
IwQYMBaAFBFvlMd20nNSm0x2gVozlQkeOuoyMA0GCSqGSIb3DQEBCwUAA4IBAQCE
YKIpEf2256SsQTMGWMvLduXpxpwF22uHsVza0AiH4XjYMOsY/gVkDQ1bSYFB1tjL
83+irXVlIy7lTDo8mmecVnzNQn/Uj7NZuHEPlnvEDWQl8lqJ0gEZXUoWVIE3Q1SQ
BgUQy4bS/Qs73hE1YQK3ohN39N9oCslFCCDXR/Xx1jyfnxKJfJRmxyCGqE2r0rnN
Px3eJKByqTowlOoD3iR2RVUdrB58fEPdOdIxeHCoQBAh1Qa+wr1+F9xs0a5U32Z5
fNTDQDCZyjX0a+D801nhYzKxHoWZ7pHvOIduyuifdaPAJ2euUtyXzc8mNvy+uQLy
36d/PS7kC17naEzq6PRv
-----END CERTIFICATE----
INDEXER_CERT

cat <<'ROOT_CA' > $TMP_DIR/root-ca.pem
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIUQJM/TzRysFfye4EQFIjqrZOrMbgwDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTExOTA5MzIzM1oXDTM0MTExNzA5MzIzM1owNTEOMAwG
A1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApDYWxpZm9ybmlh
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA60S6g32m/9fyTfPcxXDk
HjMHIZaW9Ho/fhGuNFY6qZpAX5b3swZsVTqqbEgEtsZ8ycWfv27GalgcSY7adf8j
WvXtqOsPyhK+INLSGtsyFzn7zgvoWyLZW8mvdv4eVYLestb7JNumNrRD1RUthlp8
waJirATW+HvMMCvm/LJicKl6WZI7BSSZdrjDv5wyMIcz4ODqG7FG1ExLX8EDs6dK
+/T+qVuTjXR19C6zBk7thYAZ7wSpLY2wCg/RSdNa3lSdcyXvpzTAYbNiujBuivaj
qyQzGKSFFDCJ0TybcvU/PM4gTz/R/Uvgai/KuOhQkaO+/7sTLN8SE1Xm70BrOz3e
iQIDAQABo1MwUTAdBgNVHQ4EFgQUEW+Ux3bSc1KbTHaBWjOVCR466jIwHwYDVR0j
BBgwFoAUEW+Ux3bSc1KbTHaBWjOVCR466jIwDwYDVR0TAQH/BAUwAwEB/zANBgkq
hkiG9w0BAQsFAAOCAQEAZ5CRoWTBlC2cTZIpNW/CErpyVLBppAOq7kODsLflyQ5y
BjfxL5SvUk8DC2bgbUPtb9FoXiS6aBj+X/2aRRiIdx8b28tebtI4W3jvXiCWszXh
DniTmLExDQhbVRsbDBKPcZFJ3jBuNWv84WeTE4gx8aeKD1HeD1Zp5i4ogmkbIJcQ
HLF/BUt13M2hu6anHQ8OoT4mMndk+myKojg7qSPC0aCEitdZj45g5EDdGLFKLGsu
F0RNf+C2vSX886X2qEehsBW4efY/OLJTL8wmCP1902bDEwQd9R5DYdEfEuazbZce
Y7P+4aM7jCRv0i1tibLa0h7pubpgM2Jo9YoYmefFDQ==
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
  openssl req -new -key "$TMP_DIR/indexer-key.pem" -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=node-1" -out "$TMP_DIR/indexer.csr"
  echo 'subjectAltName=DNS:node-1' > "$TMP_DIR/indexer.ext"
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