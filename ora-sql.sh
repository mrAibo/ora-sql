#!/bin/bash

#############################################################################
# Name: ora_sql.sh
# Beschreibung: SQL-Ausführungstool für Oracle-Datenbanken.
#              Unterstützt Benutzer-/SYSDBA-Authentifizierung und SQL-Dateien.
# Autor: Aleksej Voronin
# Datum: Oktober 2024
# Version: 1.27
#
# Verwendung: ./oracle_script.sh [-u user] [SID] [command|file.sql]
#
# Beispiele:
#   ./ora_sql.sh                          # Status als SYSDBA
#   ./ora_sql.sh -u scott "select * ..."  # SQL als Benutzer
#   ./ora_sql.sh script.sql               # SQL-Datei ausführen
#############################################################################

# Farbdefinitionen
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

usage() {
    cat << EOF
${BOLD}${BLUE}Verwendung:${RESET} $0 [-u user] [SID] [command|file.sql]

${BOLD}${YELLOW}Beschreibung:${RESET}
  Dieses Skript vereinfacht die Ausführung von SQL-Befehlen und SQL-Skripten in Oracle-Datenbanken.
  Es unterstützt sowohl SYSDBA-Zugriff als auch benutzerbasierte Verbindungen.

${BOLD}${YELLOW}Argumente:${RESET}
  ${GREEN}-u user${RESET}     Der Oracle-Benutzer (optional). Standard ist 'sysdba'.
  ${GREEN}SID${RESET}         Die Oracle SID (optional). Wenn nicht angegeben, wird eine Liste zur Auswahl angezeigt
             oder die einzige verfügbare SID automatisch verwendet.
  ${GREEN}command|file.sql${RESET} Der auszuführende SQL-Befehl oder der Pfad zu einer SQL-Skriptdatei.
             Standardmäßig wird 'status' ausgeführt, wenn nichts angegeben ist.

${BOLD}${YELLOW}Beispiele:${RESET}
  ${BLUE}1. Status der Standarddatenbank abfragen:${RESET}
     $0
     # Zeigt den Status der Datenbank mit Standard SYSDBA-Rechten

  ${BLUE}2. Status einer bestimmten Datenbank abfragen:${RESET}
     $0 myoradb
     # Zeigt den Status der Datenbank 'myoradb'

  ${BLUE}3. Einen benutzerdefinierten SQL-Befehl ausführen:${RESET}
     $0 'select sysdate from dual'
     # Führt eine einfache Datums-Abfrage aus

  ${BLUE}4. Einen benutzerdefinierten SQL-Befehl auf einer bestimmten Datenbank ausführen:${RESET}
     $0 myoradb 'select * from v\$version'
     # Zeigt die Oracle-Version der Datenbank 'myoradb'

  ${BLUE}5. Einen komplexeren SQL-Befehl ausführen:${RESET}
     $0 'select owner, table_name from all_tables where rownum <= 5'
     # Listet die ersten 5 Tabellen auf

  ${BLUE}6. Eine SQL-Skriptdatei ausführen:${RESET}
     $0 /pfad/zu/ihrer/script.sql
     # Führt mehrere SQL-Befehle aus einer Datei aus

  ${BLUE}7. Eine SQL-Skriptdatei auf einer bestimmten Datenbank ausführen:${RESET}
     $0 myoradb /pfad/zu/ihrer/script.sql
     # Führt Skript auf der Datenbank 'myoradb' aus

  ${BLUE}8. Als bestimmter Benutzer ausführen:${RESET}
     $0 -u system 'select * from dba_users'
     # Führt Befehl als SYSTEM-Benutzer aus

  ${BLUE}9. Als bestimmter Benutzer auf spezifischer Datenbank:${RESET}
     $0 -u system myoradb 'select * from dba_tables'
     # Führt Befehl als SYSTEM-Benutzer auf 'myoradb' aus

${BOLD}${YELLOW}Hinweise:${RESET}
  - Ohne -u Option werden die Befehle als SYSDBA ausgeführt
  - Das Semikolon am Ende des SQL-Befehls ist optional
  - Wenn keine SID angegeben wird und mehrere verfügbar sind, werden Sie zur Auswahl aufgefordert
  - SQL-Befehle mit Sonderzeichen müssen in einfache Anführungszeichen gesetzt werden
  - SQL-Skriptdateien müssen die Erweiterung .sql haben
  - SQL-Skriptdateien können mehrere SQL-Anweisungen enthalten, eine pro Zeile
  - Kommentarzeilen in SQL-Dateien (beginnend mit --) werden ignoriert
  - Bei Nicht-SYSDBA-Benutzern wird nach einem Passwort gefragt
  - Für Systemabfragen (z.B. v\$-Views) werden SYSDBA-Rechte benötigt

${BOLD}${YELLOW}Typische Anwendungsfälle:${RESET}
  ${BLUE}1. Datenbankstatus prüfen:${RESET}
     $0
     # Schnelle Statusprüfung

  ${BLUE}2. Ad-hoc Abfragen:${RESET}
     $0 'select count(*) from mytable'
     # Einzelne Abfrage ausführen

  ${BLUE}3. Wartungsarbeiten:${RESET}
     $0 maintenance.sql
     # Mehrere Wartungsbefehle aus Datei ausführen

  ${BLUE}4. Benutzeroperationen:${RESET}
     $0 -u system 'select username, created from dba_users'
     # Administrative Abfragen als Systembenutzer

${BOLD}${YELLOW}Exit Status:${RESET}
  0  Erfolgreich
  1  Fehler (falsche Argumente, Verbindungsfehler, SQL-Fehler)

${BOLD}${YELLOW}Umgebungsvariablen:${RESET}
  ORACLE_SID     Wird automatisch gesetzt basierend auf der Auswahl/Eingabe
  ORACLE_HOME    Wird automatisch aus /etc/oratab ermittelt
  PATH           Wird um $ORACLE_HOME/bin erweitert

EOF
    exit 1
}

# Funktion zum Auflisten und Auswählen einer SID
select_sid() {
    local sids=($(awk -F: '{ print $1 }' /etc/oratab | grep -v '^#' | grep -v '^$'))

    if [ ${#sids[@]} -eq 0 ]; then
        echo "${RED}Fehler: Keine SIDs in /etc/oratab gefunden.${RESET}"
        exit 1
    elif [ ${#sids[@]} -eq 1 ]; then
        echo "${GREEN}Nur eine SID gefunden: ${BOLD}${sids[0]}${RESET}"
        ORACLE_SID=${sids[0]}
    else
        echo "${YELLOW}Verfügbare SIDs:${RESET}"
        select sid in "${sids[@]}"; do
            if [ -n "$sid" ]; then
                ORACLE_SID=$sid
                break
            fi
        done
    fi
}

# Überprüfe auf Hilfe-Option
if [[ "$1" == "-h" || "$1" == "-?" ]]; then
    usage
fi

# Verarbeite die Argumente
if [ $# -eq 0 ]; then
    select_sid
    SQL_COMMAND='status'
elif [ $# -eq 1 ]; then
    if grep -q "^$1:" /etc/oratab; then
        ORACLE_SID=$1
        SQL_COMMAND='status'
    else
        select_sid
        SQL_COMMAND="$1"
    fi
elif [ $# -eq 2 ]; then
    ORACLE_SID=$1
    SQL_COMMAND="$2"
else
    echo "${RED}Fehler: Zu viele Argumente.${RESET}"
    usage
fi

# Überprüfe, ob ORACLE_SID gesetzt wurde
if [ -z "$ORACLE_SID" ]; then
    echo "${RED}Fehler: Keine gültige Oracle SID ausgewählt.${RESET}"
    exit 1
fi

# Setze die Oracle-Umgebungsvariablen
export ORACLE_SID
ORACLE_HOME=$(grep "^$ORACLE_SID:" /etc/oratab | cut -d: -f2)
export ORACLE_HOME
export PATH=$ORACLE_HOME/bin:$PATH

# Funktion zur Ausführung des SQL-Befehls oder SQL-Skripts
execute_sql_command() {
    if [ "$SQL_COMMAND" = "status" ]; then
        sqlplus -S / as sysdba <<EOF
set pagesize 0 feedback off heading off echo off;
select status from v\$instance;
exit;
EOF
    elif [[ "$SQL_COMMAND" == *.sql ]]; then
        if [ -f "$SQL_COMMAND" ]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Ignoriere leere Zeilen und Kommentare
                if [[ -z "${line// }" || "${line:0:2}" == "--" ]]; then
                    continue
                fi
                sqlplus -S / as sysdba <<EOF
set pagesize 50 linesize 100 feedback on heading on echo on;
$line
exit;
EOF
            done < "$SQL_COMMAND"
        else
            echo "${RED}Fehler: SQL-Skriptdatei '$SQL_COMMAND' nicht gefunden.${RESET}"
            exit 1
        fi
    else
        # Entferne Semikolon am Ende, falls vorhanden
        SQL_COMMAND="${SQL_COMMAND%;}"
        sqlplus -S / as sysdba <<EOF
set pagesize 50 linesize 100 feedback on heading on echo on;
$SQL_COMMAND;
exit;
EOF
    fi
}

# Führe den SQL-Befehl oder das SQL-Skript aus
if [[ "$SQL_COMMAND" == *.sql ]]; then
    echo "${BLUE}Führe SQL-Skript '${BOLD}${SQL_COMMAND}${RESET}${BLUE}' auf der Datenbank '${BOLD}${ORACLE_SID}${RESET}${BLUE}' aus...${RESET}"
else
    echo "${BLUE}Führe '${BOLD}${SQL_COMMAND}${RESET}${BLUE}' auf der Datenbank '${BOLD}${ORACLE_SID}${RESET}${BLUE}' aus...${RESET}"
fi

RESULT=$(execute_sql_command)

# Zeige das Ergebnis an
if [ "$SQL_COMMAND" = "status" ]; then
    echo "${GREEN}Status der Datenbank '${BOLD}${ORACLE_SID}${RESET}${GREEN}': ${BOLD}${RESULT}${RESET}"
else
    echo "${GREEN}Befehl wurde ausgeführt. Ergebnis:${RESET}"
    echo "${YELLOW}${RESULT}${RESET}"
fi
