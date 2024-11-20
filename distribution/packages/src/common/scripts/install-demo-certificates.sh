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
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCOsmzee/YLi+ng
6IpOAqyvRZ7ccXYMcUzY4nwLmB5rDGDpnxOIg2REPaUXXgV8gbUl10bvzeSY53Sp
udkjVVrmaWm8bB1IkspvdoUtmHR1BriilbaHjQN1y0QTlvBZKwMYfhbZKAspUHZ5
NekIoqUKcRqkuEh0yA7pyo/DooxOxuGg9IT2loDeFHsSfUsEVD+0UnMA2+dIS6Fo
Hd6fTXTUT13OSIr0msvv5EKyABXI/0GONY12qwnzG4VccHLDiX0/9G5hYVfql4hG
RatXyGXIK9jMm5x4GZ1MwJFvUcFSVG/PSaDcPMMDtRSxouxHXn9QkvsJRVHwiGoU
hkTo3jexAgMBAAECggEAC0Mo1Yx6GGI0FNS1qb+LSpAXoDVySDwfARUrDi005WUG
NxofjAw2uy4UXBpHG5MPLYvmpOGes7S83/JzoVbIxFu4hS8RRpuTT6XOkBEyy9O6
edaQH/WwurjOyC8HDDqZVXMKMZx3+QxJNXrcSBqyJPdVT3/d9B2gE7KxkxK+uS7a
DyN7yDzBzO3zxBG+8ub05AJCauaLSKX3/PjUfLT+xyv/vMUEQlvbWnTVlSthMPZs
6W/TmuBjFCHkVSIviu9/DAWewse5R/dB0VEsS3PUXZVzBWm9KV5KZNipZmFyAKu+
eLD2Tj0YWZTicfgKRV121RhgxOl4ICI8gRSasCPDCwKBgQDAylmDVsGAtnMOj7Lu
kv9yKCEDl4ssLOJc0xEYVwtuqhUmuYUO9HOQQms7M8xVt7vXVGfvAeWdwiPeBAoA
+lXBA8J7gcQA73s2dNr4oIBhfVVtWUh3IKgYdc36VQEMAaZR54RY7pLeErsb6ppd
g1pLBK7iJmSCPSE7B59lsuY2iwKBgQC9e4mDwQPLPPMHAC3dabB5KiQZwbX7wm+Y
n5nOMwByfuuNIqI5VyFulwTE+ZBoOd29Ie+eRdpJMvkqOhwfbKYwBZ8Q0kbyk3JZ
Kfvtp8JfCof+YDUy/wcF1cgjYyBcH7hHzdCqFjpIyKDiSlZ4xV2m97f05A3fVdgk
w9h00IlOMwKBgDJzQWVrSIvkMsu2sv5XnV1EPw9vks3mmP3theW2sZkuDQbrOXSm
Z69ykhkV/vzXbeJ1hhU3i9zytuwcZnnHCLXPxA8J8D7GbJndjofNiIr6f2Z0HNB/
zT1JZrOBlxqLO/jm+u1C0VAn2qr9g5PBEdnbyeAIZ/jlAlMuNXopjLDtAoGBAJWf
wrQmqz9GzsW9b3pCphbXnxAzteeq3wKPLR31iinfbVPSgHV1BzJT0HFWfKDA6Qcb
kCLUGA3rUXP11RU/b2/GUJgw49NTeV1NWOGOsl7oawEEqZ2uYrZJ3TOMaBY2+gbB
UD+vM7EbtGdcujG98DkTrdCUcRvlprtJZ1i+/12fAoGAVRLDy5caWQUSCVj6Zuas
UyXNmQKXrBJK60v4HLGQYpZ9ncNMSHAuOs+vW+qalnVc6dlARzQwAjKIASO+TO1K
Ee93b88KgEL3C52XakuzJjbQckTCZRoPveAAzIFjUCAjNpdMAh+J24wYRH0sBpAj
MS7UaisCnq1cN9iqGpbgZIw=
-----END PRIVATE KEY-----
ADMIN_KEY

cat <<'ADMIN_CERT' > $TMP_DIR/admin.pem
-----BEGIN CERTIFICATE-----
MIIDDjCCAfYCFBlGGzUW/Jh5FZTKzj0D1GeE5vlIMA0GCSqGSIb3DQEBCwUAMDUx
DjAMBgNVBAsMBVdhenVoMQ4wDAYDVQQKDAVXYXp1aDETMBEGA1UEBwwKQ2FsaWZv
cm5pYTAeFw0yNDExMjAwOTQ2NTdaFw0zNDExMTgwOTQ2NTdaMFIxCzAJBgNVBAYT
AlVTMRMwEQYDVQQHDApDYWxpZm9ybmlhMQ4wDAYDVQQKDAVXYXp1aDEOMAwGA1UE
CwwFV2F6dWgxDjAMBgNVBAMMBWFkbWluMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAjrJs3nv2C4vp4OiKTgKsr0We3HF2DHFM2OJ8C5geawxg6Z8TiINk
RD2lF14FfIG1JddG783kmOd0qbnZI1Va5mlpvGwdSJLKb3aFLZh0dQa4opW2h40D
dctEE5bwWSsDGH4W2SgLKVB2eTXpCKKlCnEapLhIdMgO6cqPw6KMTsbhoPSE9paA
3hR7En1LBFQ/tFJzANvnSEuhaB3en0101E9dzkiK9JrL7+RCsgAVyP9BjjWNdqsJ
8xuFXHByw4l9P/RuYWFX6peIRkWrV8hlyCvYzJuceBmdTMCRb1HBUlRvz0mg3DzD
A7UUsaLsR15/UJL7CUVR8IhqFIZE6N43sQIDAQABMA0GCSqGSIb3DQEBCwUAA4IB
AQB23eHCwWy5F/AmitvPo5Urd55OmLauNPIA1ZaPGqAlbUvwfUY8oDmvD1Hjwt3S
LbKV/9h9JIQO8WZA/jwX3Mq1ErFY+YYvh4EAHaIPZ1mtp11kPCOdhlG0DXlbaNx6
9Yd9Gx5GXQVR4LD5tUUqkpcdtVoie7cxq+T0sW0F8VuCuf5PRsOA9zJdgyYteqBA
gvH3Xlmg/C5r81GP8Esd95kefUEyr0X5ua1QEdHrOt/I5v0aVG7gitlny9ajYcRt
+dWDnmkrSclc4aqXWee3aJG/cXLondSaE4pwOfEcQbFAileJV6rrBBi4Zw9rXeTP
4PNMmNvU9fzYnQughosSJ1aQ
-----END CERTIFICATE-----
ADMIN_CERT

cat <<'INDEXER_KEY' > $TMP_DIR/indexer-key.pem
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDJ1T/pR0s+5L+4
vczpqm57r0F8NpNNC3xHryUkxMuIGThrDMIAbyQcg3Anbgym9TRyjqEMJigAETdh
ZLtpaG/7zXJFqP5V63syMlW+DeFEXd3tnWfZGD4+jP11aPuXGeCnMI6pSnWIWwEi
ayKSgstAFL5zIvm/9A5uZfSMhWwt2L+nmwX2o6ZYDi4KFAOxtafMey53t7dyHsnj
j9pLg85Lthl+HkRt+1cU0gl8+O3drisoUoDxK7+JU406x9cLocWONWCP9vf13mdB
qVs9z4+ThIspkvUsj5sVpfqgS9AAPDbSSF2oskU8/0E2dZqis+qqQofrtPuT/SCc
oKBD2I0fAgMBAAECggEACRQyn8e5NscLaMAA67Hi7mVfyLqbvad6m67hONoxXZnk
08vrHiHhufafoOZuY0Q8a7rGu8krm3UqzJK/a2prPyRqs396kVraW9Ovz7DIJU8j
oICoHzfb9OxaqmFij9V2KY8hm7PhvZR6ZJX1JCoGAofsWTmFioDr9UNY0MlfqGA3
K3Z4ZRUDejaMDC5BwCE0MUhmpg7Iac/DAiqIIO3+niHlrbiu8Xr3cMIpvndwVUP0
fznPXZP3WGH3m8Kl0aL8DZY6QxUtA0wCZ0iETOSSkIJExEkD2G01bW3MZPsq8A8F
PLcsvvJJeuJHaZI95rvtQ9NicopOeeCz42dHOvGl4QKBgQDhpGGcW9tm87ExlnPa
IaMmN5O1BRxdmV2PKuge8xkBaIbKvMlWinNUJfk/uSB05Nzu0JnKp4VGo/Us5awp
CYI/2Cetby/gS1/Lt7tbP+t5knxnuHI7A74XgLJeBHsn8F0TmpMsG5KvJqk40EVU
DMfc2tgqGhxNjh9BYT7I0RnsbQKBgQDk/NRYRpmnUW4oVCnk7UEGDhRJ/ndb4RN7
KWlbLNBEXcGPZWzWxoj5OyAgM5dGMnP949ouLZKXx7rF9QrenPkqp50ri8/Em3g1
IXhId2Ocrvveypcp4d3blKvmAaC6ifhhw6feAIdoe2/ijPLXAA2/VGVOXjWYeJCb
JC6NRNFQOwKBgBaVHAvJCbFJDF/ZHekj2q81ervwMgGQGtP8SFTooYUJkAv0TvYx
Tw+J6WMeRQhN62qfR/UHRQhn2l7O8ab9w6JeIMJz0UfSY1kBH2gngoqdRYQf6pbL
bhfuEmvkaOr7XGVc4APXEpwi82azOW0LBmmtIVs9V73PToN9lwoEG2MVAoGAbmPc
UnomlNzSyCpaz/v4ftzGty0viWGmLJe4LLYb6Plx2JlCsP+hBNWWFTAJ21NzS5BO
nDhoFTe6OLh69vqhvAh14opSLSvt9V8fR4AWy3AoCC2OViiG9dZkUEu0mnjs/uR9
xq5mmN35ADSG1VM3TWd4NyF/oPNucvwsXPoyFgUCgYALt80x1DPDvU38VH2lkEpw
KGZ6DGRPZ57KnHhqFkJM0OhQDarpzWLLtRsRXQER7aFlyWweiBIAGvSfJ3FlUcAC
DKSDKyitI4b1MN6CoPsppmYMNLrKNWCOtkyEw/Z/PVT/qWh52mDpFtCktXMsx9zh
KRsSS+2lWzjZf+GclfdW6g==
-----END PRIVATE KEY-----
INDEXER_KEY

cat <<'INDEXER_CERT' > $TMP_DIR/indexer.pem
-----BEGIN CERTIFICATE-----
MIIDnjCCAoagAwIBAgIUf2ZlGp+vdTu97/s+wLgjSwGasp8wDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTEyMDA5NDY1N1oXDTM0MTExODA5NDY1N1owUzELMAkG
A1UEBhMCVVMxEzARBgNVBAcMCkNhbGlmb3JuaWExDjAMBgNVBAoMBVdhenVoMQ4w
DAYDVQQLDAVXYXp1aDEPMA0GA1UEAwwGbm9kZS0xMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAydU/6UdLPuS/uL3M6apue69BfDaTTQt8R68lJMTLiBk4
awzCAG8kHINwJ24MpvU0co6hDCYoABE3YWS7aWhv+81yRaj+Vet7MjJVvg3hRF3d
7Z1n2Rg+Poz9dWj7lxngpzCOqUp1iFsBImsikoLLQBS+cyL5v/QObmX0jIVsLdi/
p5sF9qOmWA4uChQDsbWnzHsud7e3ch7J44/aS4POS7YZfh5EbftXFNIJfPjt3a4r
KFKA8Su/iVONOsfXC6HFjjVgj/b39d5nQalbPc+Pk4SLKZL1LI+bFaX6oEvQADw2
0khdqLJFPP9BNnWaorPqqkKH67T7k/0gnKCgQ9iNHwIDAQABo4GHMIGEMEIGA1Ud
EQQ7MDmIBSoDBAUFgg13YXp1aC5pbmRleGVygglsb2NhbGhvc3SHBH8AAAGHEAAA
AAAAAAAAAAAAAAAAAAEwHQYDVR0OBBYEFKJBim0BuZ5u6q6KWjNw0OpCGDo/MB8G
A1UdIwQYMBaAFGVOKnPMQPyMBAqJcQT32bXJ73eLMA0GCSqGSIb3DQEBCwUAA4IB
AQBGir3mgwjJEPgQUIacJvTPsSCX1m58oS7ggOHyUt2Ee0qhRrw7Jyaafq827AMb
XPudqa4MlL6DzLXsYFKLll7LmWsFoQEyJ5+GCjiQaWqyFPeOZ5icvMccDqIz45YB
CyODIQfFJgrEqtTK5n3wQQF1S7ff3n+4KW4Rponc+NU9koIeIcpt86Ndj3H/hJRz
7JkC2bBj8raERtKRgJ7P+GKOvXECNRKRtIeoECKrvRQcde6/nvFUnNGBnP4l8+l9
9joZe14kEe4L+A4Q2lbdm5n0AyxwfWHUPTSxYvqWoiGUPQCcy24ZukMnvGXMYEbI
W2t4ic2dpo6rvGokuUyTU79/
-----END CERTIFICATE-----
INDEXER_CERT

cat <<'ROOT_CA' > $TMP_DIR/root-ca.pem
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIUI3Vwl1LkObBnyu7xpm7BG1OiBFswDQYJKoZIhvcNAQEL
BQAwNTEOMAwGA1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApD
YWxpZm9ybmlhMB4XDTI0MTEyMDA5NDY1N1oXDTM0MTExODA5NDY1N1owNTEOMAwG
A1UECwwFV2F6dWgxDjAMBgNVBAoMBVdhenVoMRMwEQYDVQQHDApDYWxpZm9ybmlh
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqyFE8D26/f4MeaJDKD4C
siGJeMWy5CwqWDvrmDTpjFaJcKmFYh9DFjgu8bgg4NvzVPaVxsDAKgvnA6SS8ool
rWP9HBn/ofDIxxOJuWqKKjGE3U2wF59xIICgcce0eQOtzhFNUoqfqFbOZrQGiWdU
xFetmKjdeAGTyKoWmSDX4qw5H9tKSVvIAIdl3GnK3KolCCQy1BeH8tAzuXfSKGoB
XLrLazUspUr1ICZX0UbLlP9uvr+xMswnUaQqUoW6lsX9LlpkGxwEDbBlPx4W1Vij
ODxnXcQum8Pdw5Lnfe82p3Y/89C3WRZSlLU7rFhkQuMgDjpXluap/L/Su3rmzsb6
FQIDAQABo1MwUTAdBgNVHQ4EFgQUZU4qc8xA/IwEColxBPfZtcnvd4swHwYDVR0j
BBgwFoAUZU4qc8xA/IwEColxBPfZtcnvd4swDwYDVR0TAQH/BAUwAwEB/zANBgkq
hkiG9w0BAQsFAAOCAQEASGL3El7iI0XN7DXc4YHHj3j5lk2ZRjD69OiCBT0dLi6B
NCBdg2WpjnzRWHVfTHHgwg/N4vS2MQXD1D5LJNFl9TY8bP3Pq7n0ZOTF+imUlIfm
Ui39q/YlhFus6T33r+lSYEEAzRi1e2+Lk22eCNtxu5VPof3BqNI/sL5FzH1p4Get
foi6F0S5pmYrNsej3eo6oGfBJ5spu6DpanEGWvPqAmqoYiUuru/YNajP2xd39qEh
zktTmZw19StcKdznK0rOe6iR5ninMbruJcqgUERkNMfSxRQBEGGDs75vbX0PJ9cZ
MD5/joGKExUSdA9LRi6qXLCp2ZM8E9ZR4jOYH01jMQ==
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
  echo 'subjectAltName=subjectAltName=RID:1.2.3.4.5.5,DNS:wazuh.indexer,DNS:localhost,IP:127.0.0.1,IP:0:0:0:0:0:0:0:1' > "$TMP_DIR/indexer.ext"
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