#!/bin/sh

# Copyright (C) 2026, Wazuh Inc.
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.
#
# The indexer's credential helper. It belongs to the wazuh-indexer package and is used only by
# it: bin/resolve-credentials.sh sources it, and tools/wazuh-certs-tool.sh and
# tools/wazuh-passwords-tool.sh carry a copy of it. It is a library: sourcing it performs no
# action and changes nothing in the caller's shell.
#
# Everything is under the indexer's own configuration directory, /etc/wazuh-indexer:
#
#   export/                  root:wazuh-indexer 0750. What this indexer hands to the other
#     credentials.env        components on the same host: WAZUH_INDEXER_ADMIN_PASSWORD,
#                            WAZUH_INDEXER_KIBANASERVER_PASSWORD and
#                            WAZUH_INDEXER_MANAGER_PASSWORD (root:root 0600).
#     ca.pem                 This indexer's CA certificate (root:wazuh-indexer 0640).
#   ca/                      root:wazuh-indexer 0750. root-ca.pem (root:wazuh-indexer 0640) and
#                            root-ca.key (root:root 0400). Minted here when absent, which the
#                            marker .wazuh-indexer-bootstrap-ca records. A pair staged here by
#                            the operator before the install carries no marker; it is used as
#                            it is and never removed.
#   local.env                Optional, root:root 0600, the operator's. Values read before
#                            anything else: a password to use instead of generating one, or
#                            WAZUH_INDEXER_CERT_SANS. Never written by the package.
#
# export/ and ca/ can be entered by the service group, and nothing more: OpenSearch and the
# security plugin walk the whole configuration directory at start-up and fail on a directory
# they cannot enter. No file under the configuration directory is readable by others, because
# the security plugin flags every one that is.
#
# Every file read here is a regular file (not a symbolic link) owned by root that nobody else
# can write, in a directory with the same properties; export/ and ca/ may carry the service
# group. Anything else is reported as UNSAFE and neither repaired nor followed. Writes go to a
# temporary file in the target directory followed by a rename. There is no lock: this package is
# the only writer.
#
# Public functions
# ----------------
#   wazuh_env_get_file            Prints the path of export/credentials.env.
#   wazuh_local_env_file          Prints the path of local.env.
#   wazuh_export_get_dir          Prints the path of export/.
#   wazuh_ca_get_dir              Prints the CA directory: WAZUH_CA_DIR from the environment, for
#                                 wazuh-certs-tool.sh, or ca/ by default.
#   wazuh_service_group           Prints the service group, or root where the account is absent.
#   wazuh_local_get KEY           Prints the value of KEY in local.env. Returns 0 when found,
#                                 1 when absent, 2 when the file is unusable.
#   wazuh_env_get KEY             Prints the value of KEY: local.env first, then
#                                 export/credentials.env. Returns 0 when found, 1 when absent,
#                                 2 when a file is unusable.
#   wazuh_env_set KEY VALUE       Publishes KEY in export/credentials.env.
#   wazuh_env_unset KEY           Removes KEY from export/credentials.env.
#   wazuh_env_check FILE          Reports every line of FILE that is not a comment, a blank
#                                 line or a KEY=VALUE assignment this library can read.
#                                 Returns 0 when the file is usable or absent.
#   wazuh_check_dir PATH [any-group]
#                                 0 when PATH is a directory root may trust, 1 when absent,
#                                 2 when present but refused (UNSAFE printed to stderr). The
#                                 group may be anything only when "any-group" is given.
#   wazuh_check_file PATH         The same for a regular file.
#   wazuh_check_secret PATH       The same, and the file is readable by nobody but root.
#   wazuh_ca_validate             0 when the CA directory holds a trusted CA certificate, and a
#                                 key that matches it when there is one.
#   wazuh_ca_ensure               Mints the CA when the directory holds neither certificate nor
#                                 key, validates what is there otherwise, and publishes
#                                 export/ca.pem.
#   wazuh_ca_is_minted            0 when the CA in ca/ was minted by this package.
#   wazuh_ca_publish_file FILE    Publishes the CA certificate in FILE as export/ca.pem.
#   wazuh_password_generate       Prints 32 characters from the password alphabet, with at
#                                 least one of each of its four classes.
#   wazuh_password_validate VALUE The rule every supplied password must meet: 12 to 64
#                                 characters from A-Z a-z 0-9 . , _ + : @ % ^ = ~ - with at
#                                 least one uppercase letter, one lowercase letter, one digit
#                                 and one symbol. The rejected value is never printed.
#
# Host tools: sh, coreutils (stat, od, tr, cut, mktemp, chmod, chown, mv, cat, rm, mkdir,
# uname, sha256sum), openssl, getent (glibc) and restorecon when the host has it. Nothing else.
# Capture password output; never run with xtrace around a secret.

_WAZUH_CONF=${WAZUH_INDEXER_CONFIG_DIR-/etc/wazuh-indexer}
_WAZUH_EXPORT=${_WAZUH_CONF}/export
_WAZUH_CA_DEFAULT=${_WAZUH_CONF}/ca
_WAZUH_CA=${WAZUH_CA_DIR-${_WAZUH_CA_DEFAULT}}
_WAZUH_LOCAL=${_WAZUH_CONF}/local.env
_WAZUH_CA_MARKER=.wazuh-indexer-bootstrap-ca
_WAZUH_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,_+:@%^=~-'

# The group that may enter export/ and ca/ and read the CA certificates. Root where the service
# account is absent: wazuh-certs-tool.sh on a host without the indexer.
if getent group wazuh-indexer > /dev/null 2>&1; then
    _WAZUH_GROUP=wazuh-indexer
else
    _WAZUH_GROUP=root
fi

_wazuh_error() (
    printf '%s\n' "wazuh-indexer-credentials: $*" >&2
)

wazuh_env_get_file() (
    printf '%s\n' "${_WAZUH_EXPORT}/credentials.env"
)

wazuh_local_env_file() (
    printf '%s\n' "${_WAZUH_LOCAL}"
)

wazuh_export_get_dir() (
    printf '%s\n' "${_WAZUH_EXPORT}"
)

wazuh_ca_get_dir() (
    printf '%s\n' "${_WAZUH_CA}"
)

wazuh_service_group() (
    printf '%s\n' "${_WAZUH_GROUP}"
)

# -- trust checks ---------------------------------------------------------------------------------

# The reason a mode is refused: a write bit for the group or for others. The last two octal
# digits are group and others; 2, 3, 6 and 7 carry the write bit.
_wazuh_mode_refused() {
    case $1 in
        *[2367][0-7]) printf '%s' "writable by its group (mode $1)"; return 0 ;;
        *[2367])      printf '%s' "writable by others (mode $1)"; return 0 ;;
    esac
    return 1
}

# 0 when $1 is a directory root may trust: present, a directory, not a symbolic link, owned by
# root, writable by nobody but root. 1 when absent, 2 when present but refused, with the reason
# printed as "UNSAFE <path>: <reason>".
wazuh_check_dir() (
    _d=$1
    if [ ! -e "$_d" ] && [ ! -L "$_d" ]; then
        return 1
    fi
    if [ -L "$_d" ]; then
        _wazuh_unsafe "$_d" "a symbolic link"
        return 2
    fi
    if [ ! -d "$_d" ]; then
        _wazuh_unsafe "$_d" "not a directory"
        return 2
    fi
    _st=$(stat -c '%u %a' "$_d" 2>/dev/null) || { _wazuh_unsafe "$_d" "cannot be examined"; return 2; }
    if [ "${_st%% *}" != 0 ]; then
        _wazuh_unsafe "$_d" "owned by uid ${_st%% *}, not root"
        return 2
    fi
    if _why=$(_wazuh_mode_refused "${_st#* }"); then
        _wazuh_unsafe "$_d" "$_why"
        return 2
    fi
    return 0
)

# The same rules for a regular file.
wazuh_check_file() (
    _f=$1
    if [ ! -e "$_f" ] && [ ! -L "$_f" ]; then
        return 1
    fi
    if [ -L "$_f" ]; then
        _wazuh_unsafe "$_f" "a symbolic link"
        return 2
    fi
    if [ ! -f "$_f" ]; then
        _wazuh_unsafe "$_f" "not a regular file"
        return 2
    fi
    _st=$(stat -c '%u %a' "$_f" 2>/dev/null) || { _wazuh_unsafe "$_f" "cannot be examined"; return 2; }
    if [ "${_st%% *}" != 0 ]; then
        _wazuh_unsafe "$_f" "owned by uid ${_st%% *}, not root"
        return 2
    fi
    if _why=$(_wazuh_mode_refused "${_st#* }"); then
        _wazuh_unsafe "$_f" "$_why"
        return 2
    fi
    return 0
)

# A file holding a secret: the rules of wazuh_check_file, and no read bit for the group or for
# others either. 0 trusted, 1 absent, 2 refused.
wazuh_check_secret() (
    _f=$1
    wazuh_check_file "$_f"
    case $? in
        1) return 1 ;;
        2) return 2 ;;
    esac
    _m=$(stat -c '%a' "$_f" 2>/dev/null)
    case $_m in
        *[4567])      _wazuh_unsafe "$_f" "readable by others (mode $_m)"; return 2 ;;
        *[4567][0-7]) _wazuh_unsafe "$_f" "readable by its group (mode $_m)"; return 2 ;;
    esac
    return 0
)

_wazuh_unsafe() (
    printf 'UNSAFE %s: %s\n' "$1" "$2" >&2
)

# Create a root-owned directory with the given mode and group, or verify the one already there.
# mkdir without -p: the parent must already exist and be root's, so that nobody else could have
# put something in the way. The owner and mode are set only on a directory this call created.
_wazuh_root_dir() (
    _d=$1
    _m=$2
    _g=${3-root}
    if [ ! -e "$_d" ] && [ ! -L "$_d" ]; then
        _parent=${_d%/*}
        [ -n "$_parent" ] || _parent=/
        wazuh_check_dir "$_parent" > /dev/null 2>&1 || {
            _wazuh_error "$_parent is not a directory root may write into"
            return 1
        }
        mkdir -m "$_m" "$_d" 2>/dev/null || {
            _wazuh_error "cannot create $_d"
            return 1
        }
        # Still not a link: the parent is root's, so only root could have raced this.
        if [ -L "$_d" ] || [ ! -d "$_d" ]; then
            _wazuh_error "$_d is not the directory just created"
            return 1
        fi
        chown "root:$_g" "$_d" && chmod "$_m" "$_d" || return 1
        if command -v restorecon > /dev/null 2>&1; then
            restorecon "$_d" > /dev/null 2>&1 || true
        fi
    fi
    wazuh_check_dir "$_d"
    case $? in
        0) return 0 ;;
        *) return 1 ;;
    esac
)

# Write standard input to a root-owned file atomically: a temporary file in the same directory,
# then a rename over the target. Nothing is ever written through an existing path.
_wazuh_write_file() (
    _f=$1
    _m=$2
    _g=${3-root}
    _dir=${_f%/*}
    [ -n "$_dir" ] || _dir=/
    wazuh_check_dir "$_dir" > /dev/null 2>&1 || {
        _wazuh_error "$_dir is not a directory root may write into"
        return 1
    }
    if [ -L "$_f" ] || { [ -e "$_f" ] && [ ! -f "$_f" ]; }; then
        _wazuh_error "refusing to replace $_f: not a regular file"
        return 1
    fi
    _umask=$(umask)
    umask 077
    _t=$(mktemp "${_f}.XXXXXX") || { umask "$_umask"; return 1; }
    umask "$_umask"
    if ! cat > "$_t"; then
        rm -f "$_t"
        return 1
    fi
    chown "root:$_g" "$_t" && chmod "$_m" "$_t" && mv -f "$_t" "$_f" || {
        rm -f "$_t"
        return 1
    }
    if command -v restorecon > /dev/null 2>&1; then
        restorecon "$_f" > /dev/null 2>&1 || true
    fi
)

# -- KEY=value files ------------------------------------------------------------------------------

_wazuh_valid_name() {
    case $1 in
        ''|*[!A-Za-z0-9_]*|[0-9]*) return 1 ;;
    esac
    return 0
}

# The value of one KEY=VALUE line, unquoted. Plain values carry no blank, quote, backslash,
# dollar, backquote or hash; single-quoted values are literal; double-quoted values unescape
# \\ \" \$ and \`. Those are the forms the other components write and read. Returns 1 when the
# value needs quoting it does not have.
_wazuh_unquote() {
    _uq=$1
    case $_uq in
        \'*\')
            _uq=${_uq#\'}
            _uq=${_uq%\'}
            case $_uq in *\'*) return 1 ;; esac
            ;;
        \"*\")
            _uq=${_uq#\"}
            _uq=${_uq%\"}
            _out=
            while [ -n "$_uq" ]; do
                _c=${_uq%"${_uq#?}"}
                _uq=${_uq#?}
                if [ "$_c" = '\' ] && [ -n "$_uq" ]; then
                    _n=${_uq%"${_uq#?}"}
                    case $_n in
                        '\'|'"'|'$'|'`') _c=$_n; _uq=${_uq#?} ;;
                    esac
                elif [ "$_c" = '"' ]; then
                    return 1
                fi
                _out=$_out$_c
            done
            _uq=$_out
            ;;
        *'"'*|*"'"*|*' '*|*'	'*|*'\'*|*'$'*|*'`'*|*'#'*)
            return 1
            ;;
    esac
    printf '%s' "$_uq"
}

# Print the value of KEY in FILE. 0 found, 1 absent, 2 file unusable. The file is parsed, never
# sourced. The last assignment wins, as it would in a shell.
_wazuh_file_get() (
    _file=$1
    _key=$2
    wazuh_check_file "$_file"
    case $? in
        1) return 1 ;;
        2) return 2 ;;
    esac
    _found=1
    _value=
    while IFS= read -r _line || [ -n "$_line" ]; do
        case $_line in
            "$_key="*) ;;
            *) continue ;;
        esac
        if ! _value=$(_wazuh_unquote "${_line#*=}"); then
            _wazuh_error "$_file: the value of $_key needs quoting"
            return 2
        fi
        _found=0
    done < "$_file"
    [ "$_found" -eq 0 ] && printf '%s' "$_value"
    return $_found
)

# The value of KEY in local.env alone: the operator's settings that are never published, such as
# the certificate names. 0 found, 1 absent, 2 the file is unusable.
wazuh_local_get() (
    _wazuh_valid_name "${1-}" || { _wazuh_error "invalid key name"; return 2; }
    _wazuh_file_get "$_WAZUH_LOCAL" "$1"
)

wazuh_env_get() (
    _wazuh_valid_name "${1-}" || { _wazuh_error "invalid key name"; return 2; }
    _v=$(_wazuh_file_get "$_WAZUH_LOCAL" "$1")
    case $? in
        0) printf '%s' "$_v"; return 0 ;;
        2) return 2 ;;
    esac
    _v=$(_wazuh_file_get "${_WAZUH_EXPORT}/credentials.env" "$1")
    case $? in
        0) printf '%s' "$_v"; return 0 ;;
        2) return 2 ;;
    esac
    return 1
)

# Every line of FILE must be blank, a comment, or an assignment this library can read.
wazuh_env_check() (
    _file=$1
    wazuh_check_file "$_file"
    case $? in
        1) return 0 ;;
        2) return 1 ;;
    esac
    _n=0
    _bad=0
    while IFS= read -r _line || [ -n "$_line" ]; do
        _n=$((_n + 1))
        _stripped=${_line#"${_line%%[! 	]*}"}
        case $_stripped in
            ''|'#'*) continue ;;
        esac
        case $_line in
            *=*) ;;
            *)
                printf 'INVALID %s: line %s is not a KEY=VALUE assignment\n' "$_file" "$_n" >&2
                _bad=1
                continue
                ;;
        esac
        if ! _wazuh_valid_name "${_line%%=*}"; then
            printf 'INVALID %s: line %s has an invalid key name\n' "$_file" "$_n" >&2
            _bad=1
            continue
        fi
        if ! _wazuh_unquote "${_line#*=}" > /dev/null; then
            printf 'INVALID %s: line %s has a value that needs quoting\n' "$_file" "$_n" >&2
            _bad=1
        fi
    done < "$_file"
    return $_bad
)

# Rewrite export/credentials.env without KEY, then with KEY=VALUE appended when VALUE is given.
_wazuh_export_mutate() (
    _key=$1
    _set=$2
    _val=${3-}
    _wazuh_root_dir "$_WAZUH_EXPORT" 0750 "$_WAZUH_GROUP" || return 1
    _file=${_WAZUH_EXPORT}/credentials.env
    wazuh_check_file "$_file"
    case $? in
        2) return 1 ;;
    esac
    {
        if [ -f "$_file" ]; then
            while IFS= read -r _line || [ -n "$_line" ]; do
                case $_line in
                    "$_key="*) continue ;;
                esac
                printf '%s\n' "$_line"
            done < "$_file"
        else
            printf '%s\n' "# Published by wazuh-indexer for the manager and the dashboard on this host. Do not edit."
        fi
        if [ -n "$_set" ]; then
            case $_val in
                *[!A-Za-z0-9.,_+:@%^=~-]*)
                    # Double-quoted, with \ " $ and ` escaped: the form _wazuh_unquote reads.
                    _q=
                    while [ -n "$_val" ]; do
                        _c=${_val%"${_val#?}"}
                        _val=${_val#?}
                        case $_c in '\'|'"'|'$'|'`') _c="\\$_c" ;; esac
                        _q=$_q$_c
                    done
                    printf '%s="%s"\n' "$_key" "$_q"
                    ;;
                *) printf '%s=%s\n' "$_key" "$_val" ;;
            esac
        fi
    } | _wazuh_write_file "$_file" 0600
)

wazuh_env_set() (
    _wazuh_valid_name "${1-}" || { _wazuh_error "invalid key name"; return 1; }
    [ "$#" -eq 2 ] || { _wazuh_error "usage: wazuh_env_set KEY VALUE"; return 1; }
    _nl='
'
    case $2 in
        *"$_nl"*) _wazuh_error "a value cannot span lines"; return 1 ;;
    esac
    _wazuh_export_mutate "$1" set "$2"
)

wazuh_env_unset() (
    _wazuh_valid_name "${1-}" || { _wazuh_error "invalid key name"; return 1; }
    [ -f "${_WAZUH_EXPORT}/credentials.env" ] || [ -L "${_WAZUH_EXPORT}/credentials.env" ] || return 0
    _wazuh_export_mutate "$1" ""
)

# -- the CA ---------------------------------------------------------------------------------------

wazuh_ca_is_minted() (
    [ -f "${_WAZUH_CA}/${_WAZUH_CA_MARKER}" ]
)

# 0 when the CA directory holds a trusted, self-signed CA certificate, with a matching private key
# when there is one. A key without a certificate is an error.
wazuh_ca_validate() (
    _pem=${_WAZUH_CA}/root-ca.pem
    _key=${_WAZUH_CA}/root-ca.key
    wazuh_check_dir "$_WAZUH_CA" || { _wazuh_error "$_WAZUH_CA is missing or not trusted"; return 1; }
    wazuh_check_file "$_pem" || { _wazuh_error "$_pem is missing or not trusted"; return 1; }
    openssl x509 -in "$_pem" -noout > /dev/null 2>&1 || { _wazuh_error "$_pem is not a certificate"; return 1; }
    _ext=$(openssl x509 -in "$_pem" -noout -ext basicConstraints 2>/dev/null)
    case $_ext in
        *CA:TRUE*) ;;
        *) _wazuh_error "$_pem is not a CA certificate"; return 1 ;;
    esac
    openssl verify -no_check_time -CAfile "$_pem" "$_pem" > /dev/null 2>&1 || {
        _wazuh_error "$_pem is not self-signed"
        return 1
    }
    if [ -e "$_key" ] || [ -L "$_key" ]; then
        wazuh_check_file "$_key" || { _wazuh_error "$_key is not trusted"; return 1; }
        _st=$(stat -c '%a' "$_key" 2>/dev/null)
        case $_st in
            400|600) ;;
            *) _wazuh_error "$_key must be mode 0400 or 0600"; return 1 ;;
        esac
        _a=$(openssl x509 -in "$_pem" -noout -pubkey 2>/dev/null | sha256sum)
        _b=$(openssl pkey -in "$_key" -pubout 2>/dev/null | sha256sum)
        [ -n "$_a" ] && [ "${_a%% *}" = "${_b%% *}" ] || {
            _wazuh_error "$_key does not match $_pem"
            return 1
        }
    fi
    return 0
)

# Publish the CA certificate in FILE as export/ca.pem, for the other components on this host,
# when it differs from what is there.
wazuh_ca_publish_file() (
    _pem=$1
    [ -d "$_WAZUH_CONF" ] || return 0
    wazuh_check_file "$_pem" || { _wazuh_error "$_pem is missing or not trusted"; return 1; }
    _wazuh_root_dir "$_WAZUH_EXPORT" 0750 "$_WAZUH_GROUP" || return 1
    wazuh_check_file "${_WAZUH_EXPORT}/ca.pem"
    case $? in
        0) [ "$(cat "${_WAZUH_EXPORT}/ca.pem")" = "$(cat "$_pem")" ] && return 0 ;;
        2) return 1 ;;
    esac
    _wazuh_write_file "${_WAZUH_EXPORT}/ca.pem" 0640 "$_WAZUH_GROUP" < "$_pem"
)

# Publish the CA this package keeps in ca/. A directory given with WAZUH_CA_DIR is someone
# else's and is never published.
_wazuh_ca_publish() (
    [ "$_WAZUH_CA" = "$_WAZUH_CA_DEFAULT" ] || return 0
    wazuh_ca_publish_file "${_WAZUH_CA}/root-ca.pem"
)

# Mint the CA when the directory holds neither certificate nor key; check what is there otherwise.
# A key without a certificate, or a certificate whose key does not match it, is an error, not
# something to repair. Then publish the certificate.
wazuh_ca_ensure() (
    _wazuh_root_dir "$_WAZUH_CA" 0750 "$_WAZUH_GROUP" || return 1
    _pem=${_WAZUH_CA}/root-ca.pem
    _key=${_WAZUH_CA}/root-ca.key

    if [ ! -e "$_pem" ] && [ ! -e "$_key" ] && [ ! -L "$_pem" ] && [ ! -L "$_key" ]; then
        _host=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n 2>/dev/null)
        _host=${_host%%.*}
        [ -n "$_host" ] || _host=wazuh-indexer
        _tmp=$(mktemp -d "${_WAZUH_CA}/mint.XXXXXX") || return 1
        chmod 700 "$_tmp"
        (
            umask 077
            openssl req -x509 -new -newkey rsa:2048 -nodes -sha256 -days 3650 \
                -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=wazuh-indexer-${_host}" \
                -addext "basicConstraints = critical, CA:TRUE" \
                -addext "keyUsage = critical, keyCertSign, cRLSign" \
                -addext "subjectKeyIdentifier = hash" \
                -keyout "$_tmp/root-ca.key" -out "$_tmp/root-ca.pem" > /dev/null 2>&1
        ) || { rm -rf "$_tmp"; _wazuh_error "openssl could not mint the CA"; return 1; }
        chown root:root "$_tmp/root-ca.key" && chmod 0400 "$_tmp/root-ca.key" &&
        chown "root:$_WAZUH_GROUP" "$_tmp/root-ca.pem" && chmod 0640 "$_tmp/root-ca.pem" &&
        mv -f "$_tmp/root-ca.key" "$_key" && mv -f "$_tmp/root-ca.pem" "$_pem" || {
            rm -rf "$_tmp"
            return 1
        }
        rm -rf "$_tmp"
        printf '' | _wazuh_write_file "${_WAZUH_CA}/${_WAZUH_CA_MARKER}" 0600 || return 1
        if command -v restorecon > /dev/null 2>&1; then
            restorecon "$_key" "$_pem" > /dev/null 2>&1 || true
        fi
    fi

    wazuh_ca_validate || return 1
    _wazuh_ca_publish
)

# -- passwords ------------------------------------------------------------------------------------

# An unbiased index below $1: two bytes of /dev/urandom, rejecting values above the largest
# multiple of the limit.
_wazuh_random_below() (
    _limit=$1
    _ceiling=$((65536 - (65536 % _limit)))
    while :; do
        _n=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d '[:space:]') || return 1
        case $_n in ''|*[!0-9]*) return 1 ;; esac
        if [ "$_n" -lt "$_ceiling" ]; then
            printf '%s' $((_n % _limit))
            return 0
        fi
    done
)

_wazuh_random_char() (
    _i=$(_wazuh_random_below "${#1}") || return 1
    printf '%s' "$1" | cut -c "$((_i + 1))"
)

_wazuh_replace_char() (
    _text=$1; _pos=$2; _char=$3
    _prefix=
    [ "$_pos" -le 1 ] || _prefix=$(printf '%s' "$_text" | cut -c "1-$((_pos - 1))")
    _suffix=$(printf '%s' "$_text" | cut -c "$((_pos + 1))-")
    printf '%s%s%s' "$_prefix" "$_char" "$_suffix"
)

# 32 characters, with one character of each class at four distinct positions, so that the four
# classes are present by construction rather than by generate-and-retry.
wazuh_password_generate() (
    _pw=
    while [ "${#_pw}" -lt 32 ]; do
        _c=$(_wazuh_random_char "$_WAZUH_ALPHABET") || return 1
        _pw=$_pw$_c
    done
    _p1=$(( $(_wazuh_random_below 32) + 1 ))
    while :; do _p2=$(( $(_wazuh_random_below 32) + 1 )); [ "$_p2" -ne "$_p1" ] && break; done
    while :; do _p3=$(( $(_wazuh_random_below 32) + 1 )); [ "$_p3" -ne "$_p1" ] && [ "$_p3" -ne "$_p2" ] && break; done
    while :; do _p4=$(( $(_wazuh_random_below 32) + 1 )); [ "$_p4" -ne "$_p1" ] && [ "$_p4" -ne "$_p2" ] && [ "$_p4" -ne "$_p3" ] && break; done
    _pw=$(_wazuh_replace_char "$_pw" "$_p1" "$(_wazuh_random_char abcdefghijklmnopqrstuvwxyz)")
    _pw=$(_wazuh_replace_char "$_pw" "$_p2" "$(_wazuh_random_char ABCDEFGHIJKLMNOPQRSTUVWXYZ)")
    _pw=$(_wazuh_replace_char "$_pw" "$_p3" "$(_wazuh_random_char 0123456789)")
    _pw=$(_wazuh_replace_char "$_pw" "$_p4" "$(_wazuh_random_char '.,_+:@%^=~-')")
    wazuh_password_validate "$_pw" > /dev/null 2>&1 || return 1
    printf '%s\n' "$_pw"
)

wazuh_password_validate() (
    [ "$#" -eq 1 ] || { _wazuh_error 'usage: wazuh_password_validate VALUE'; return 1; }
    _pw=$1
    case $_pw in
        *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,_+:@%^=~-]*)
            _wazuh_error 'password must only contain characters from A-Z a-z 0-9 . , _ + : @ % ^ = ~ -'
            return 1 ;;
    esac
    if [ "${#_pw}" -lt 12 ] || [ "${#_pw}" -gt 64 ]; then
        _wazuh_error 'password must contain between 12 and 64 characters'
        return 1
    fi
    case $_pw in *[abcdefghijklmnopqrstuvwxyz]*) ;; *) _wazuh_error 'password must contain at least one lowercase letter'; return 1 ;; esac
    case $_pw in *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) ;; *) _wazuh_error 'password must contain at least one uppercase letter'; return 1 ;; esac
    case $_pw in *[0123456789]*) ;; *) _wazuh_error 'password must contain at least one digit'; return 1 ;; esac
    case $_pw in *[.,_+:@%^=~-]*) ;; *) _wazuh_error 'password must contain at least one symbol from . , _ + : @ % ^ = ~ -'; return 1 ;; esac
)
