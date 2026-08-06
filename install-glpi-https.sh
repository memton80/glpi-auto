#!/bin/bash
#==============================================================================
#  GLPI AUTO - Installation automatisee de GLPI sur Debian 12
#
#  Interface console maison (aucune dependance a whiptail / dialog) :
#    - panneau "Machine" en haut a droite (IP, nom, pare-feu, ports 80/443)
#    - grand panneau de configuration avec menus depliants
#    - bouton INSTALLER en bas
#    - ecrans d'installation avec Tux anime et barre de progression reelle
#
#  Auteur : Alexandre
#==============================================================================

set -o pipefail

#------------------------------------------------------------------ constantes
SCRIPT_VERSION="2.0"
LOGFILE="/var/log/glpi-install.log"
STEP_LOG="/tmp/glpi-step.log"
APT_STATUS="/tmp/glpi-apt-status.log"
WGET_LOG="/tmp/glpi-wget.log"
GLPI_DIR="/var/www/html/glpi"
GLPI_DATA="/var/lib/glpi"
GLPI_ARCHIVE="/tmp/glpi.tgz"
SSL_DIR="/etc/ssl/glpi"
MYSQL_CRED="/root/.mysql_credentials"
GLPI_FALLBACK_URL="https://github.com/glpi-project/glpi/releases/download/11.0.0/glpi-11.0.0.tgz"

export PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin"
export DEBIAN_FRONTEND=noninteractive

#==============================================================================
#  1. TERMINAL : locale, couleurs, caracteres de cadre
#==============================================================================

setup_locale() {
    if [[ "$(locale charmap 2>/dev/null)" != "UTF-8" ]]; then
        if locale -a 2>/dev/null | grep -qiE '^c\.utf-?8$'; then
            export LC_ALL="C.UTF-8" LANG="C.UTF-8"
        elif locale -a 2>/dev/null | grep -qiE '^fr_FR\.utf-?8$'; then
            export LC_ALL="fr_FR.UTF-8" LANG="fr_FR.UTF-8"
        fi
    fi
    if [[ "$(locale charmap 2>/dev/null)" == "UTF-8" ]]; then
        UTF8=1
    else
        UTF8=0
    fi
}

setup_charset() {
    if (( UTF8 )); then
        BX_TL='┌'; BX_TR='┐'; BX_BL='└'; BX_BR='┘'; BX_H='─'; BX_V='│'
        BAR_FULL='█'; BAR_EMPTY='░'; GROUND='─'
    else
        BX_TL='+'; BX_TR='+'; BX_BL='+'; BX_BR='+'; BX_H='-'; BX_V='|'
        BAR_FULL='#'; BAR_EMPTY='.'; GROUND='-'
    fi
}

# THEME vaut "dark" (fond sombre) ou "light" (fond clair).
THEME="dark"

# Demande au terminal la couleur de son fond (OSC 11) pour choisir la palette.
# En cas de non-reponse on retombe sur COLORFGBG puis sur le theme sombre.
detect_theme() {
    case "${GLPI_THEME:-}" in
        light|clair)  THEME="light"; return ;;
        dark|sombre)  THEME="dark";  return ;;
    esac

    THEME="dark"
    local resp="" r g b lum saved=""
    if [[ -t 0 && -t 1 ]]; then
        saved=$(stty -g 2>/dev/null)
        stty -echo 2>/dev/null
        printf '\e]11;?\e\\'
        IFS= read -rs -d '\' -t 0.3 resp 2>/dev/null
        [[ -n $saved ]] && stty "$saved" 2>/dev/null
    fi
    if [[ $resp =~ rgb:([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4}) ]]; then
        # les composantes font 1 a 4 chiffres hexa : on ne garde que le poids fort
        r=$(( 16#${BASH_REMATCH[1]:0:2} ))
        g=$(( 16#${BASH_REMATCH[2]:0:2} ))
        b=$(( 16#${BASH_REMATCH[3]:0:2} ))
        lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
        (( lum > 128 )) && THEME="light"
        return
    fi
    # COLORFGBG = "avant-plan;arriere-plan", fond 7 ou 15 = clair
    if [[ ${COLORFGBG:-} =~ ^[0-9]+\;([0-9]+)$ ]]; then
        case "${BASH_REMATCH[1]}" in
            7|15) THEME="light" ;;
        esac
    fi
}

toggle_theme() {
    if [[ $THEME == dark ]]; then THEME="light"; else THEME="dark"; fi
    setup_colors
}

setup_colors() {
    local ncol=8
    command -v tput >/dev/null 2>&1 && ncol=$(tput colors 2>/dev/null || echo 8)
    [[ "$ncol" =~ ^[0-9]+$ ]] || ncol=8

    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_REV=$'\e[7m'

    if (( ncol >= 256 )); then
        if [[ $THEME == light ]]; then
            C_FRAME=$'\e[38;5;245m'      # cadre inactif
            C_FRAME_ON=$'\e[38;5;28m'    # cadre du panneau actif
            C_TITLE=$'\e[38;5;25m'       # titres de panneaux
            C_LABEL=$'\e[38;5;238m'
            C_VALUE=$'\e[38;5;16m'
            C_OK=$'\e[38;5;28m'
            C_WARN=$'\e[38;5;130m'
            C_ERR=$'\e[38;5;124m'
            C_MUTED=$'\e[38;5;242m'
            C_SEC=$'\e[38;5;54m'
            C_SEL=$'\e[48;5;253m'
            C_BTN=$'\e[38;5;28m'
            C_BTN_ON=$'\e[48;5;28m\e[38;5;231m'
            C_TUX=$'\e[38;5;16m'
            C_TUX_FEET=$'\e[38;5;130m'
            C_BAR=$'\e[38;5;28m'
            C_BAR_BG=$'\e[38;5;252m'
        else
            C_FRAME=$'\e[38;5;240m'
            C_FRAME_ON=$'\e[38;5;114m'
            C_TITLE=$'\e[38;5;81m'
            C_LABEL=$'\e[38;5;250m'
            C_VALUE=$'\e[38;5;231m'
            C_OK=$'\e[38;5;114m'
            C_WARN=$'\e[38;5;214m'
            C_ERR=$'\e[38;5;203m'
            C_MUTED=$'\e[38;5;244m'
            C_SEC=$'\e[38;5;147m'
            C_SEL=$'\e[48;5;238m'
            C_BTN=$'\e[38;5;114m'
            C_BTN_ON=$'\e[48;5;114m\e[38;5;16m'
            C_TUX=$'\e[38;5;255m'
            C_TUX_FEET=$'\e[38;5;214m'
            C_BAR=$'\e[38;5;114m'
            C_BAR_BG=$'\e[38;5;238m'
        fi
    else
        if [[ $THEME == light ]]; then
            C_FRAME=$'\e[90m'; C_FRAME_ON=$'\e[32m'; C_TITLE=$'\e[34m'
            C_LABEL=$'\e[30m'; C_VALUE=$'\e[30m'; C_OK=$'\e[32m'
            C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_MUTED=$'\e[90m'
            C_SEC=$'\e[35m'; C_SEL=$'\e[7m'; C_BTN=$'\e[32m'
            C_BTN_ON=$'\e[42m\e[97m'; C_TUX=$'\e[30m'; C_TUX_FEET=$'\e[33m'
            C_BAR=$'\e[32m'; C_BAR_BG=$'\e[37m'
        else
            C_FRAME=$'\e[90m'; C_FRAME_ON=$'\e[32m'; C_TITLE=$'\e[36m'
            C_LABEL=$'\e[37m'; C_VALUE=$'\e[97m'; C_OK=$'\e[32m'
            C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_MUTED=$'\e[90m'
            C_SEC=$'\e[36m'; C_SEL=$'\e[100m'; C_BTN=$'\e[32m'
            C_BTN_ON=$'\e[42m\e[30m'; C_TUX=$'\e[97m'; C_TUX_FEET=$'\e[33m'
            C_BAR=$'\e[32m'; C_BAR_BG=$'\e[90m'
        fi
    fi
}

tui_start() {
    printf '\e[?1049h'   # ecran alternatif
    printf '\e[?25l'     # curseur cache
    stty -echo 2>/dev/null
}

tui_stop() {
    stty echo 2>/dev/null
    printf '\e[?25h'
    printf '\e[?1049l'
}

cursor_show() { printf '\e[?25h'; }
cursor_hide() { printf '\e[?25l'; }

on_resize() { RESIZED=1; }

compute_layout() {
    COLS=$(tput cols 2>/dev/null || echo 80)
    ROWS=$(tput lines 2>/dev/null || echo 24)
    [[ "$COLS" =~ ^[0-9]+$ ]] || COLS=80
    [[ "$ROWS" =~ ^[0-9]+$ ]] || ROWS=24

    RIGHT_W=36
    (( COLS < 100 )) && RIGHT_W=32
    (( COLS < 90 ))  && RIGHT_W=30

    HEAD_Y=1;  HEAD_H=3
    BODY_Y=$(( HEAD_Y + HEAD_H ))
    FOOT_H=3
    FOOT_Y=$(( ROWS - FOOT_H ))
    BODY_H=$(( FOOT_Y - BODY_Y ))

    FORM_X=1
    FORM_W=$(( COLS - RIGHT_W - 1 ))
    RIGHT_X=$(( COLS - RIGHT_W + 1 ))
    MACH_H=10
    HELP_H=$(( BODY_H - MACH_H ))
    # sur un ecran court on rogne le panneau machine pour garder tous les
    # raccourcis visibles (8 lignes suffisent a afficher ses six informations)
    if (( HELP_H < 9 && MACH_H > 8 )); then
        MACH_H=8
        HELP_H=$(( BODY_H - MACH_H ))
    fi
    (( HELP_H < 3 )) && { MACH_H=$(( BODY_H - 3 )); HELP_H=3; }

    FORM_ROWS=$(( BODY_H - 2 ))
}

term_too_small() { (( COLS < 74 || ROWS < 20 )); }

#==============================================================================
#  2. PRIMITIVES DE DESSIN
#==============================================================================

BUF=""

put() { BUF+=$'\e['"$1;$2"'H'"$3"; }

# pad_str <texte> <largeur> -> PAD (coupe ou complete avec des espaces)
pad_str() {
    local s=$1 w=$2 n
    n=${#s}
    if (( n > w )); then
        PAD=${s:0:w}
    else
        printf -v PAD '%s%*s' "$s" $(( w - n )) ''
    fi
}

# rep_char <caractere> <n> -> REPC
rep_char() {
    local n=$2
    (( n <= 0 )) && { REPC=""; return; }
    printf -v REPC '%*s' "$n" ''
    REPC=${REPC// /$1}
}

# draw_box <y> <x> <h> <w> <titre> <couleur>
draw_box() {
    local y=$1 x=$2 h=$3 w=$4 title=$5 col=$6
    local inner=$(( w - 2 )) i top
    rep_char "$BX_H" "$inner"
    local hline=$REPC
    if [[ -n $title ]]; then
        local t=" $title " tl
        tl=${#t}
        if (( tl > inner - 3 )); then
            t=" ${title:0:inner-6}.. "
            tl=${#t}
        fi
        rep_char "$BX_H" $(( inner - 1 - tl ))
        top="${BX_TL}${BX_H}${C_TITLE}${C_BOLD}${t}${C_RESET}${col}${REPC}${BX_TR}"
    else
        top="${BX_TL}${hline}${BX_TR}"
    fi
    put "$y" "$x" "${col}${top}"
    printf -v PAD '%*s' "$inner" ''
    for (( i = 1; i < h - 1; i++ )); do
        put $(( y + i )) "$x" "${col}${BX_V}${C_RESET}${PAD}${col}${BX_V}"
    done
    put $(( y + h - 1 )) "$x" "${col}${BX_BL}${hline}${BX_BR}${C_RESET}"
}

# draw_bar <y> <x> <largeur> <pourcentage>
draw_bar() {
    local y=$1 x=$2 w=$3 pct=$4
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    local barw=$(( w - 6 ))
    local fill=$(( barw * pct / 100 ))
    rep_char "$BAR_FULL" "$fill";            local f=$REPC
    rep_char "$BAR_EMPTY" $(( barw - fill )); local e=$REPC
    printf -v PAD '%4s%%' "$pct"
    put "$y" "$x" "${C_BAR}${f}${C_BAR_BG}${e}${C_RESET}${C_BOLD}${PAD}${C_RESET}"
}

#==============================================================================
#  3. TUX (ASCII, 4 images d'animation)
#==============================================================================

TUX_H=7
TUX_W=12
declare -a TUX_0 TUX_1 TUX_2 TUX_3

load_tux() {
    local l
    while IFS= read -r l; do TUX_0+=("$l"); done <<'ART0'
    .--.
   |o_o |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
\___)=(___/
ART0
    while IFS= read -r l; do TUX_1+=("$l"); done <<'ART1'
    .--.
   |o_o |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
(___)=(___)
ART1
    while IFS= read -r l; do TUX_2+=("$l"); done <<'ART2'
    .--.
   |-_- |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
\___)=(___/
ART2
    while IFS= read -r l; do TUX_3+=("$l"); done <<'ART3'
    .--.
   |o_o |
   |:_/ |
  \\   / /
 (|     | )
/'\_   _/`\
(___)=(___)
ART3
}

# tux_line <image 0-3> <ligne 0-6> -> TUXL
tux_line() {
    case $1 in
        0) TUXL=${TUX_0[$2]} ;;
        1) TUXL=${TUX_1[$2]} ;;
        2) TUXL=${TUX_2[$2]} ;;
        *) TUXL=${TUX_3[$2]} ;;
    esac
}

#==============================================================================
#  4. INFORMATIONS MACHINE
#==============================================================================

MI_HOST=""; MI_IP=""; MI_OS=""
MI_FW=""; MI_FW_ST="warn"
MI_P80=""; MI_P80_ST="warn"
MI_P443=""; MI_P443_ST="warn"

get_ip() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z $ip ]] && ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
    [[ -z $ip ]] && ip="127.0.0.1"
    printf '%s' "$ip"
}

get_os() {
    local os=""
    [[ -r /etc/os-release ]] && os=$(. /etc/os-release 2>/dev/null && printf '%s' "$PRETTY_NAME")
    [[ -z $os ]] && os=$(uname -sr)
    printf '%s' "$os"
}

detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -qiE '^(Status|Statut)[[:space:]]*:[[:space:]]*(active|actif)'; then
            MI_FW="actif (ufw)"; MI_FW_ST="ok"; return
        fi
        MI_FW="inactif (ufw)"; MI_FW_ST="warn"; return
    fi
    if command -v nft >/dev/null 2>&1 && [[ -n $(nft list ruleset 2>/dev/null) ]]; then
        MI_FW="actif (nftables)"; MI_FW_ST="ok"; return
    fi
    if command -v iptables >/dev/null 2>&1 && (( $(iptables -S 2>/dev/null | wc -l) > 3 )); then
        MI_FW="actif (iptables)"; MI_FW_ST="ok"; return
    fi
    MI_FW="aucun"; MI_FW_ST="warn"
}

# port_state <port> -> PORT_TXT / PORT_ST
port_state() {
    local port=$1 line proc=""
    if command -v ss >/dev/null 2>&1; then
        line=$(ss -lntpH 2>/dev/null | awk -v p=":$port" '{ if (index($4, p) && substr($4, length($4)-length(p)+1) == p) print }')
    elif command -v netstat >/dev/null 2>&1; then
        line=$(netstat -lntp 2>/dev/null | awk -v p=":$port" '{ if (substr($4, length($4)-length(p)+1) == p) print }')
    else
        PORT_TXT="inconnu"; PORT_ST="warn"; return
    fi
    if [[ -z $line ]]; then
        PORT_TXT="libre"; PORT_ST="ok"
    else
        proc=$(printf '%s' "$line" | grep -oE '"[^"]+"' | head -n1 | tr -d '"')
        [[ -z $proc ]] && proc=$(printf '%s' "$line" | awk '{print $NF}' | cut -d/ -f2)
        if [[ -n $proc ]]; then
            PORT_TXT="occupe ($proc)"
        else
            PORT_TXT="occupe"
        fi
        PORT_ST="err"
    fi
}

collect_machine_info() {
    MI_HOST=$(hostname 2>/dev/null || printf 'inconnu')
    MI_IP=$(get_ip)
    MI_OS=$(get_os)
    detect_firewall
    port_state 80;  MI_P80=$PORT_TXT;  MI_P80_ST=$PORT_ST
    port_state 443; MI_P443=$PORT_TXT; MI_P443_ST=$PORT_ST
}

state_color() {
    case $1 in
        ok)   printf '%s' "$C_OK" ;;
        warn) printf '%s' "$C_WARN" ;;
        *)    printf '%s' "$C_ERR" ;;
    esac
}

#==============================================================================
#  5. MODELE DU FORMULAIRE
#==============================================================================

declare -a SEC_NAME SEC_OPEN
declare -a FLD_SEC FLD_KEY FLD_LABEL FLD_TYPE FLD_HINT FLD_COND
declare -A VAL

add_section() { SEC_NAME+=("$1"); SEC_OPEN+=(1); }

# add_field <cle> <libelle> <type> <valeur> <aide> [condition]
add_field() {
    FLD_SEC+=($(( ${#SEC_NAME[@]} - 1 )))
    FLD_KEY+=("$1"); FLD_LABEL+=("$2"); FLD_TYPE+=("$3")
    VAL["$1"]="$4"
    FLD_HINT+=("$5"); FLD_COND+=("${6:-}")
}

build_form() {
    add_section "Base de donnees"
    add_field db_name  "Nom de la base"          text "glpidb"   "Lettres, chiffres et tiret bas uniquement."
    add_field db_user  "Utilisateur MySQL"       text "glpiuser" "Lettres, chiffres et tiret bas uniquement."
    add_field db_auto  "Generer le mot de passe" bool "oui"      "Genere un mot de passe fort de 16 caracteres."
    add_field db_pass  "Mot de passe MySQL"      pass ""         "8 caracteres minimum, sans espace ni quote." "db_auto=non"

    add_section "Securite"
    add_field root_pass "Mot de passe root MariaDB" pass ""  "Obligatoire. Sauvegarde dans $MYSQL_CRED."
    add_field db_remote "Acces MariaDB distant"     bool "non" "Fait ecouter MariaDB sur 0.0.0.0 : a n'activer qu'avec un pare-feu."
    add_field firewall  "Configurer le pare-feu UFW" bool "oui" "N'autorise que les ports 22 (SSH), 80 et 443."

    add_section "Web et HTTPS"
    add_field domain   "Domaine ou IP du serveur" text ""     "Utilise pour le certificat et l'URL finale."
    add_field ssl      "Certificat auto-signe"    bool "oui"  "Cree un certificat HTTPS auto-signe pour le domaine."
    add_field ssl_days "Duree du certificat (j)"  num  "365"  "Nombre de jours de validite (1 a 3650)." "ssl=oui"

    add_section "Options"
    add_field uninstaller "Script de desinstallation" bool "oui" "Genere ./uninstall-glpi.sh a la fin."
    add_field tests       "Tests de verification"     bool "oui" "Verifie Apache, MariaDB et le repertoire GLPI."
}

field_index() {
    local k=$1 i
    for (( i = 0; i < ${#FLD_KEY[@]}; i++ )); do
        [[ ${FLD_KEY[i]} == "$k" ]] && { printf '%s' "$i"; return 0; }
    done
    printf '%s' "-1"
}

field_visible() {
    local c=${FLD_COND[$1]}
    [[ -z $c ]] && return 0
    local k=${c%%=*} v=${c#*=}
    [[ ${VAL[$k]} == "$v" ]]
}

declare -a VR_TYPE VR_IDX

build_rows() {
    VR_TYPE=(); VR_IDX=()
    local s i
    for (( s = 0; s < ${#SEC_NAME[@]}; s++ )); do
        VR_TYPE+=("sec"); VR_IDX+=("$s")
        if (( SEC_OPEN[s] )); then
            for (( i = 0; i < ${#FLD_KEY[@]}; i++ )); do
                (( FLD_SEC[i] == s )) || continue
                field_visible "$i" || continue
                VR_TYPE+=("fld"); VR_IDX+=("$i")
            done
        fi
        if (( s < ${#SEC_NAME[@]} - 1 )); then VR_TYPE+=("gap"); VR_IDX+=("-1"); fi
    done
}

# valeur affichee d'un champ -> DISPV / DISPC
field_display() {
    local i=$1 key=${FLD_KEY[$1]} type=${FLD_TYPE[$1]} v=${VAL[${FLD_KEY[$1]}]}
    case $type in
        bool)
            if [[ $v == oui ]]; then DISPV="< oui >"; DISPC=$C_OK
            else DISPV="< non >"; DISPC=$C_MUTED; fi
            ;;
        pass)
            if [[ -z $v ]]; then DISPV="(non defini)"; DISPC=$C_WARN
            else
                local n=${#v}; (( n > 16 )) && n=16
                rep_char '*' "$n"; DISPV=$REPC; DISPC=$C_VALUE
            fi
            ;;
        *)
            if [[ -z $v ]]; then DISPV="(vide)"; DISPC=$C_WARN
            else DISPV=$v; DISPC=$C_VALUE; fi
            ;;
    esac
}

#==============================================================================
#  6. RENDU DE L'ECRAN PRINCIPAL
#==============================================================================

SEL=0          # index de ligne selectionnee (== nb de lignes -> bouton)
SCROLL=0
STATUS_MSG=""
STATUS_KIND="info"

sel_is_button() { (( SEL >= ${#VR_TYPE[@]} )); }

adjust_scroll() {
    local n=${#VR_TYPE[@]}
    sel_is_button && return
    (( SEL < SCROLL )) && SCROLL=$SEL
    (( SEL >= SCROLL + FORM_ROWS )) && SCROLL=$(( SEL - FORM_ROWS + 1 ))
    (( SCROLL > n - FORM_ROWS )) && SCROLL=$(( n - FORM_ROWS ))
    (( SCROLL < 0 )) && SCROLL=0
}

render_header() {
    local title="GLPI AUTO - INSTALLATEUR DEBIAN 12"
    draw_box "$HEAD_Y" 1 "$HEAD_H" "$COLS" "" "$C_FRAME"
    local x=$(( (COLS - ${#title}) / 2 ))
    (( x < 2 )) && x=2
    put $(( HEAD_Y + 1 )) "$x" "${C_BOLD}${C_TITLE}${title}${C_RESET}"
    put $(( HEAD_Y + 1 )) $(( COLS - 10 )) "${C_MUTED}v${SCRIPT_VERSION}${C_RESET}"
}

render_form() {
    local col=$C_FRAME
    sel_is_button || col=$C_FRAME_ON
    draw_box "$BODY_Y" "$FORM_X" "$BODY_H" "$FORM_W" "Configuration" "$col"

    local inner=$(( FORM_W - 4 ))
    local labw=$(( inner - 22 ))
    (( labw > 34 )) && labw=34
    (( labw < 16 )) && labw=16
    local n=${#VR_TYPE[@]} r y i idx line

    for (( r = 0; r < FORM_ROWS; r++ )); do
        i=$(( SCROLL + r ))
        (( i >= n )) && break
        y=$(( BODY_Y + 1 + r ))
        idx=${VR_IDX[i]}
        case ${VR_TYPE[i]} in
            sec)
                local mark="v"
                (( SEC_OPEN[idx] )) || mark=">"
                pad_str " ${mark} ${SEC_NAME[idx]}" "$inner"
                if (( SEL == i )); then
                    put "$y" $(( FORM_X + 1 )) "${C_SEL}${C_BOLD}${C_SEC} ${PAD} ${C_RESET}"
                else
                    put "$y" $(( FORM_X + 1 )) "${C_BOLD}${C_SEC} ${PAD} ${C_RESET}"
                fi
                ;;
            fld)
                field_display "$idx"
                # -1 : on garde toujours une colonne vide entre libelle et valeur
                pad_str "    ${FLD_LABEL[idx]}" $(( labw - 1 ))
                local lab="$PAD "
                pad_str "$DISPV" $(( inner - labw ))
                local val=$PAD
                if (( SEL == i )); then
                    put "$y" $(( FORM_X + 1 )) "${C_SEL} ${C_BOLD}${C_LABEL}${lab}${DISPC}${val}${C_RESET}${C_SEL} ${C_RESET}"
                else
                    put "$y" $(( FORM_X + 1 )) " ${C_LABEL}${lab}${DISPC}${val}${C_RESET} "
                fi
                ;;
            *)
                ;;
        esac
    done

    # indicateurs de defilement
    (( SCROLL > 0 )) && put "$BODY_Y" $(( FORM_X + FORM_W - 5 )) "${C_FRAME}[^]${C_RESET}"
    (( SCROLL + FORM_ROWS < n )) && put $(( BODY_Y + BODY_H - 1 )) $(( FORM_X + FORM_W - 5 )) "${C_FRAME}[v]${C_RESET}"
}

render_machine() {
    draw_box "$BODY_Y" "$RIGHT_X" "$MACH_H" "$RIGHT_W" "Machine" "$C_FRAME"
    local inner=$(( RIGHT_W - 4 ))
    local labw=11
    local y=$(( BODY_Y + 1 ))
    local rows=(
        "Nom d'hote|$MI_HOST|"
        "Adresse IP|$MI_IP|"
        "Systeme|$MI_OS|"
        "Pare-feu|$MI_FW|$MI_FW_ST"
        "Port 80|$MI_P80|$MI_P80_ST"
        "Port 443|$MI_P443|$MI_P443_ST"
    )
    local r lab val st c
    for r in "${rows[@]}"; do
        IFS='|' read -r lab val st <<<"$r"
        c=$C_VALUE
        [[ -n $st ]] && c=$(state_color "$st")
        pad_str "$lab" "$labw"; local L=$PAD
        pad_str "$val" $(( inner - labw - 2 )); local V=$PAD
        put "$y" $(( RIGHT_X + 2 )) "${C_MUTED}${L}${C_RESET}: ${c}${V}${C_RESET}"
        y=$(( y + 1 ))
    done
    if (( MACH_H > 8 )); then
        pad_str "[r] rafraichir" $(( inner ))
        put $(( BODY_Y + MACH_H - 2 )) $(( RIGHT_X + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    fi
}

render_help() {
    local y=$(( BODY_Y + MACH_H ))
    draw_box "$y" "$RIGHT_X" "$HELP_H" "$RIGHT_W" "Raccourcis" "$C_FRAME"
    local inner=$(( RIGHT_W - 4 ))
    local keys=(
        "Haut/Bas|deplacer"
        "Entree|modifier / valider"
        "Espace|oui / non"
        "Gauche/Droite|plier / deplier"
        "r|infos machine"
        "t|theme clair/sombre"
        "q|quitter"
    )
    local i=0 k lab
    for k in "${keys[@]}"; do
        (( i >= HELP_H - 2 )) && break
        IFS='|' read -r lab k <<<"$k"
        pad_str "$lab" 14; local L=$PAD
        pad_str "$k" $(( inner - 14 )); local V=$PAD
        put $(( y + 1 + i )) $(( RIGHT_X + 2 )) "${C_BOLD}${C_LABEL}${L}${C_RESET}${C_MUTED}${V}${C_RESET}"
        i=$(( i + 1 ))
    done

    # bas du panneau : rappels utiles
    if (( HELP_H >= 14 )); then
        local notes=(
            "Installation dans"
            "  $GLPI_DIR"
            "Journal"
            "  $LOGFILE"
        )
        rep_char "$BX_H" "$inner"
        put $(( y + HELP_H - 6 )) $(( RIGHT_X + 2 )) "${C_FRAME}${REPC}${C_RESET}"
        local j=0
        for k in "${notes[@]}"; do
            pad_str "$k" "$inner"
            put $(( y + HELP_H - 5 + j )) $(( RIGHT_X + 2 )) "${C_MUTED}${PAD}${C_RESET}"
            j=$(( j + 1 ))
        done
    fi
}

render_button() {
    local col=$C_FRAME lab="[ INSTALLER ]"
    sel_is_button && col=$C_FRAME_ON
    draw_box "$FOOT_Y" 1 "$FOOT_H" "$COLS" "" "$col"
    local x=$(( (COLS - ${#lab}) / 2 ))
    if sel_is_button; then
        put $(( FOOT_Y + 1 )) "$x" "${C_BTN_ON}${C_BOLD}${lab}${C_RESET}"
    else
        put $(( FOOT_Y + 1 )) "$x" "${C_BTN}${lab}${C_RESET}"
    fi
}

render_status() {
    local txt=$STATUS_MSG c=$C_MUTED
    case $STATUS_KIND in
        err)  c=$C_ERR ;;
        ok)   c=$C_OK ;;
        warn) c=$C_WARN ;;
    esac
    if [[ -z $txt ]]; then
        if sel_is_button; then
            txt="Entree pour lancer l'installation de GLPI."
        else
            local i=${VR_IDX[$SEL]}
            if [[ ${VR_TYPE[$SEL]} == fld ]]; then
                txt=${FLD_HINT[i]}
            elif [[ ${VR_TYPE[$SEL]} == sec ]]; then
                txt="Entree ou Gauche/Droite pour plier ou deplier la section."
            fi
        fi
    fi
    pad_str " $txt" "$COLS"
    put "$ROWS" 1 "${c}${PAD}${C_RESET}"
}

render_main() {
    BUF=$'\e[2J'
    if term_too_small; then
        put 1 1 "${C_ERR}Terminal trop petit : ${COLS}x${ROWS}. Minimum requis 74x20.${C_RESET}"
        printf '%s' "$BUF"
        return
    fi
    render_header
    render_form
    render_machine
    render_help
    render_button
    render_status
    printf '%s' "$BUF"
}

#==============================================================================
#  7. SAISIE CLAVIER
#==============================================================================

KEY=""

read_key() {
    local k rest
    KEY=""
    IFS= read -rsn1 k 2>/dev/null || { KEY="NONE"; return 0; }
    case "$k" in
        "")     KEY="ENTER" ;;
        $'\e')
            IFS= read -rsn2 -t 0.05 rest 2>/dev/null
            case "$rest" in
                "[A") KEY="UP" ;;
                "[B") KEY="DOWN" ;;
                "[C") KEY="RIGHT" ;;
                "[D") KEY="LEFT" ;;
                "[H") KEY="HOME" ;;
                "[F") KEY="END" ;;
                "[5") IFS= read -rsn1 -t 0.05 2>/dev/null; KEY="PGUP" ;;
                "[6") IFS= read -rsn1 -t 0.05 2>/dev/null; KEY="PGDN" ;;
                "")   KEY="ESC" ;;
                *)    KEY="OTHER" ;;
            esac
            ;;
        " ")     KEY="SPACE" ;;
        $'\t')   KEY="TAB" ;;
        $'\x7f') KEY="BACK" ;;
        *)       KEY="CHAR:$k" ;;
    esac
}

wait_key() { local k; IFS= read -rsn1 k 2>/dev/null; }

#==============================================================================
#  8. FENETRES MODALES
#==============================================================================

# modal_box <h> <w> <titre> -> MX / MY (coin haut gauche)
modal_box() {
    local h=$1 w=$2 title=$3
    MY=$(( (ROWS - h) / 2 )); MX=$(( (COLS - w) / 2 ))
    (( MY < 1 )) && MY=1
    (( MX < 1 )) && MX=1
    BUF=""
    draw_box "$MY" "$MX" "$h" "$w" "$title" "$C_FRAME_ON"
    printf '%s' "$BUF"
}

# edit_line <y> <x> <largeur> <valeur> <masque 0/1> -> EDITED (0 = valide)
edit_line() {
    local y=$1 x=$2 w=$3 buf=$4 mask=$5 k rest disp
    cursor_show
    while :; do
        if (( mask )); then
            rep_char '*' "${#buf}"; disp=$REPC
        else
            disp=$buf
        fi
        (( ${#disp} > w )) && disp=${disp: -w}
        pad_str "$disp" "$w"
        printf '\e[%d;%dH%s%s%s' "$y" "$x" "$C_VALUE" "$PAD" "$C_RESET"
        printf '\e[%d;%dH' "$y" $(( x + ${#disp} ))
        IFS= read -rsn1 k 2>/dev/null || continue
        case "$k" in
            "") EDITED=$buf; cursor_hide; return 0 ;;
            $'\e')
                IFS= read -rsn2 -t 0.05 rest 2>/dev/null
                [[ -z $rest ]] && { cursor_hide; return 1; }
                ;;
            $'\x7f'|$'\b') buf=${buf%?} ;;
            $'\x15') buf="" ;;
            *)
                if [[ $k == [[:print:]] || $(printf '%d' "'$k" 2>/dev/null) -gt 127 ]]; then
                    (( ${#buf} < 200 )) && buf+="$k"
                fi
                ;;
        esac
    done
}

# modal_message <titre> <texte multi-lignes> [couleur]
modal_message() {
    local title=$1 text=$2 col=${3:-$C_VALUE}
    local -a lines
    local w=0 l
    while IFS= read -r l; do lines+=("$l"); (( ${#l} > w )) && w=${#l}; done <<<"$text"
    w=$(( w + 6 ))
    (( w > COLS - 4 )) && w=$(( COLS - 4 ))
    (( w < 40 )) && w=40
    local h=$(( ${#lines[@]} + 4 ))
    (( h > ROWS - 2 )) && h=$(( ROWS - 2 ))
    modal_box "$h" "$w" "$title"
    BUF=""
    local i
    for (( i = 0; i < ${#lines[@]} && i < h - 4; i++ )); do
        pad_str "${lines[i]}" $(( w - 4 ))
        put $(( MY + 1 + i )) $(( MX + 2 )) "${col}${PAD}${C_RESET}"
    done
    pad_str "Appuyez sur une touche pour continuer" $(( w - 4 ))
    put $(( MY + h - 2 )) $(( MX + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    wait_key
}

# modal_confirm <titre> <question> -> 0 = oui
modal_confirm() {
    local title=$1 text=$2 choice=0
    local -a lines
    local w=0 l
    while IFS= read -r l; do lines+=("$l"); (( ${#l} > w )) && w=${#l}; done <<<"$text"
    w=$(( w + 6 )); (( w < 44 )) && w=44
    (( w > COLS - 4 )) && w=$(( COLS - 4 ))
    local h=$(( ${#lines[@]} + 5 ))
    modal_box "$h" "$w" "$title"
    while :; do
        BUF=""
        local i
        for (( i = 0; i < ${#lines[@]}; i++ )); do
            pad_str "${lines[i]}" $(( w - 4 ))
            put $(( MY + 1 + i )) $(( MX + 2 )) "${C_VALUE}${PAD}${C_RESET}"
        done
        local yes="[ Oui ]" no="[ Non ]"
        local by=$(( MY + h - 2 )) bx=$(( MX + w - 20 ))
        if (( choice == 0 )); then
            put "$by" "$bx" "${C_BTN_ON}${C_BOLD}${yes}${C_RESET}  ${C_MUTED}${no}${C_RESET}"
        else
            put "$by" "$bx" "${C_MUTED}${yes}${C_RESET}  ${C_BTN_ON}${C_BOLD}${no}${C_RESET}"
        fi
        printf '%s' "$BUF"
        read_key
        case $KEY in
            LEFT|RIGHT|TAB) choice=$(( 1 - choice )) ;;
            ENTER) return $choice ;;
            ESC) return 1 ;;
            "CHAR:o"|"CHAR:O"|"CHAR:y"|"CHAR:Y") return 0 ;;
            "CHAR:n"|"CHAR:N") return 1 ;;
        esac
    done
}

# modal_edit <titre> <invite> <valeur> <masque> <aide> -> EDITED
modal_edit() {
    local title=$1 prompt=$2 cur=$3 mask=$4 hint=$5
    local w=64
    (( w > COLS - 4 )) && w=$(( COLS - 4 ))
    local h=9
    modal_box "$h" "$w" "$title"
    BUF=""
    pad_str "$prompt" $(( w - 4 ))
    put $(( MY + 1 )) $(( MX + 2 )) "${C_LABEL}${PAD}${C_RESET}"
    pad_str "$hint" $(( w - 4 ))
    put $(( MY + 2 )) $(( MX + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    rep_char "$BX_H" $(( w - 6 ))
    put $(( MY + 5 )) $(( MX + 3 )) "${C_FRAME}${REPC}${C_RESET}"
    pad_str "Entree : valider     Echap : annuler" $(( w - 4 ))
    put $(( MY + 6 )) $(( MX + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    edit_line $(( MY + 4 )) $(( MX + 3 )) $(( w - 6 )) "$cur" "$mask"
}

#==============================================================================
#  9. INTERACTION AVEC LE FORMULAIRE
#==============================================================================

toggle_bool() {
    local key=$1
    if [[ ${VAL[$key]} == oui ]]; then VAL[$key]="non"; else VAL[$key]="oui"; fi
}

validate_value() {
    # validate_value <type de controle> <valeur> -> 0 ok, sinon VERR
    local kind=$1 v=$2
    VERR=""
    case $kind in
        ident)
            [[ $v =~ ^[a-zA-Z0-9_]+$ ]] || VERR="Seuls les lettres, chiffres et le tiret bas sont autorises."
            ;;
        pass)
            if (( ${#v} < 8 )); then VERR="Le mot de passe doit faire au moins 8 caracteres."
            elif [[ $v =~ [\'\"\\\`\ ] ]]; then VERR="Caracteres interdits : espace, quote, double quote, antislash, accent grave."
            fi
            ;;
        host)
            [[ $v =~ ^[a-zA-Z0-9._-]+$ ]] || VERR="Domaine ou adresse IP invalide."
            ;;
        days)
            if [[ ! $v =~ ^[0-9]+$ ]]; then VERR="Saisissez un nombre de jours."
            elif (( v < 1 || v > 3650 )); then VERR="La duree doit etre comprise entre 1 et 3650 jours."
            fi
            ;;
    esac
    [[ -z $VERR ]]
}

field_check_kind() {
    case ${FLD_KEY[$1]} in
        db_name|db_user) printf 'ident' ;;
        db_pass|root_pass) printf 'pass' ;;
        domain) printf 'host' ;;
        ssl_days) printf 'days' ;;
        *) printf 'none' ;;
    esac
}

edit_field() {
    local i=$1 key=${FLD_KEY[$1]} type=${FLD_TYPE[$1]}
    local kind; kind=$(field_check_kind "$i")
    case $type in
        bool) toggle_bool "$key"; return ;;
    esac
    local mask=0
    [[ $type == pass ]] && mask=1
    while :; do
        modal_edit "${FLD_LABEL[i]}" "${FLD_LABEL[i]} :" "${VAL[$key]}" "$mask" "${FLD_HINT[i]}" || return
        local v=$EDITED
        if [[ $kind != none ]] && ! validate_value "$kind" "$v"; then
            modal_message "Valeur invalide" "$VERR" "$C_ERR"
            continue
        fi
        if (( mask )); then
            modal_edit "${FLD_LABEL[i]}" "Confirmez le mot de passe :" "" 1 "Ressaisissez la meme valeur." || return
            if [[ $EDITED != "$v" ]]; then
                modal_message "Mots de passe differents" $'Les deux saisies ne correspondent pas.\nVeuillez recommencer.' "$C_ERR"
                continue
            fi
        fi
        VAL[$key]=$v
        return
    done
}

validate_form() {
    # -> 0 si tout est bon, sinon FERR / FKEY
    FERR=""; FKEY=""
    local checks=(db_name db_user domain)
    local k kind idx
    for k in "${checks[@]}"; do
        idx=$(field_index "$k")
        kind=$(field_check_kind "$idx")
        if ! validate_value "$kind" "${VAL[$k]}"; then
            FERR="${FLD_LABEL[idx]} : $VERR"; FKEY=$k; return 1
        fi
    done
    if [[ ${VAL[db_auto]} == non ]]; then
        if ! validate_value pass "${VAL[db_pass]}"; then
            FERR="Mot de passe MySQL : $VERR"; FKEY="db_pass"; return 1
        fi
    fi
    if ! validate_value pass "${VAL[root_pass]}"; then
        FERR="Mot de passe root MariaDB : $VERR"; FKEY="root_pass"; return 1
    fi
    if [[ ${VAL[ssl]} == oui ]] && ! validate_value days "${VAL[ssl_days]}"; then
        FERR="Duree du certificat : $VERR"; FKEY="ssl_days"; return 1
    fi
    return 0
}

select_field_row() {
    local key=$1 i idx
    build_rows
    for (( i = 0; i < ${#VR_TYPE[@]}; i++ )); do
        [[ ${VR_TYPE[i]} == fld ]] || continue
        idx=${VR_IDX[i]}
        if [[ ${FLD_KEY[idx]} == "$key" ]]; then SEL=$i; adjust_scroll; return; fi
    done
}

move_sel() {
    local dir=$1 n=${#VR_TYPE[@]} i=$SEL
    while :; do
        i=$(( i + dir ))
        if (( i < 0 )); then return; fi
        if (( i > n )); then return; fi
        if (( i == n )); then SEL=$n; return; fi
        [[ ${VR_TYPE[i]} == gap ]] && continue
        SEL=$i; return
    done
}

#==============================================================================
#  10. ECRANS D'ANIMATION (TUX + BARRE DE PROGRESSION)
#==============================================================================

ANIM_MODE="download"   # download | install
STEP_LABEL=""
PCT=0
FRAME=0
ANIM_Y=0; ANIM_X=0; ANIM_W=0
TUX_Y=0; GROUND_Y=0; LABEL_Y=0; BAR_Y=0; INFO_Y=0; TITLE_Y=0

anim_layout() {
    ANIM_X=3
    ANIM_W=$(( COLS - 4 ))
    (( ANIM_W > 96 )) && { ANIM_W=96; ANIM_X=$(( (COLS - ANIM_W) / 2 + 1 )); }
    ANIM_Y=2
    local h=$(( ROWS - 3 ))
    ANIM_H=$h
    local inner_y=$(( ANIM_Y + 1 ))
    local content=13
    local free=$(( h - 2 - content ))
    (( free < 0 )) && free=0
    local top=$(( free / 2 ))
    TUX_Y=$(( inner_y + top ))
    GROUND_Y=$(( TUX_Y + TUX_H ))
    TITLE_Y=$(( GROUND_Y + 2 ))
    LABEL_Y=$(( TITLE_Y + 1 ))
    BAR_Y=$(( LABEL_Y + 1 ))
    INFO_Y=$(( BAR_Y + 1 ))
}

anim_begin() {
    ANIM_MODE=$1
    compute_layout
    anim_layout
    local title="TELECHARGEMENT DES COMPOSANTS"
    [[ $ANIM_MODE == install ]] && title="INSTALLATION"
    BUF=$'\e[2J'
    draw_box "$ANIM_Y" "$ANIM_X" "$ANIM_H" "$ANIM_W" "$title" "$C_FRAME_ON"
    pad_str " Journal complet : $LOGFILE" "$COLS"
    put "$ROWS" 1 "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    RESIZED=0
    anim_tick
}

human_size() {
    local b=$1
    if (( b >= 1048576 )); then
        printf '%d,%d Mo' $(( b / 1048576 )) $(( (b % 1048576) * 10 / 1048576 ))
    elif (( b >= 1024 )); then
        printf '%d Ko' $(( b / 1024 ))
    else
        printf '%d o' "$b"
    fi
}

anim_info_line() {
    # ligne d'information sous la barre
    if [[ $ANIM_MODE == download && -n $DL_FILE ]]; then
        local cur=0 tot=${DL_TOTAL:-0}
        [[ -f $DL_FILE ]] && cur=$(stat -c %s "$DL_FILE" 2>/dev/null || echo 0)
        if (( tot > 0 )); then
            printf '%s' "$(human_size "$cur") / $(human_size "$tot")"
            return
        fi
        (( cur > 0 )) && { printf '%s' "$(human_size "$cur") recus"; return; }
    fi
    printf '%s' ""
}

anim_tick() {
    (( RESIZED )) && { anim_begin "$ANIM_MODE"; return; }
    FRAME=$(( (FRAME + 1) % 4 ))
    local inner=$(( ANIM_W - 4 ))
    local ix=$(( ANIM_X + 2 ))
    local i x line

    # --- position de Tux ---
    if [[ $ANIM_MODE == download ]]; then
        local run=$(( inner - TUX_W - 2 ))
        (( run < 0 )) && run=0
        x=$(( ix + run * PCT / 100 ))
    else
        x=$(( ix + (inner - TUX_W) / 2 ))
    fi
    (( x < ix )) && x=$ix

    BUF=""
    for (( i = 0; i < TUX_H; i++ )); do
        tux_line "$FRAME" "$i"
        local art=$TUXL
        local before=$(( x - ix ))
        printf -v PAD '%*s' "$before" ''
        local pre=$PAD
        pad_str "$art" $(( inner - before ))
        local col=$C_TUX
        (( i >= TUX_H - 1 )) && col=$C_TUX_FEET
        put $(( TUX_Y + i )) "$ix" "${pre}${col}${PAD}${C_RESET}"
    done

    # --- sol ---
    rep_char "$GROUND" "$inner"
    put "$GROUND_Y" "$ix" "${C_FRAME}${REPC}${C_RESET}"

    # --- titre de phase ---
    local ptitle=""
    if [[ $ANIM_MODE == install ]]; then
        local dots=""
        case $FRAME in
            0) dots="" ;;
            1) dots="." ;;
            2) dots=".." ;;
            *) dots="..." ;;
        esac
        ptitle="INSTALLATION EN COURS${dots}"
    else
        ptitle="TELECHARGEMENT EN COURS"
    fi
    local px=$(( ix + (inner - ${#ptitle}) / 2 ))
    (( px < ix )) && px=$ix
    printf -v PAD '%*s' "$inner" ''
    put "$TITLE_Y" "$ix" "$PAD"
    put "$TITLE_Y" "$px" "${C_BOLD}${C_TITLE}${ptitle}${C_RESET}"

    # --- etape en cours ---
    pad_str "$STEP_LABEL" "$inner"
    put "$LABEL_Y" "$ix" "${C_LABEL}${PAD}${C_RESET}"

    # --- barre ---
    draw_bar "$BAR_Y" "$ix" "$inner" "$PCT"

    # --- information complementaire ---
    local info; info=$(anim_info_line)
    pad_str "$info" "$inner"
    put "$INFO_Y" "$ix" "${C_MUTED}${PAD}${C_RESET}"

    printf '%s' "$BUF"
}

#==============================================================================
#  11. SONDES DE PROGRESSION
#==============================================================================

probe_apt() {
    local dl=-1 pm=-1 line _a _b p
    if [[ -s $APT_STATUS ]]; then
        line=$(grep '^dlstatus:' "$APT_STATUS" 2>/dev/null | tail -n1)
        if [[ -n $line ]]; then
            IFS=: read -r _a _b p _ <<<"$line"; dl=${p%%.*}
        fi
        line=$(grep '^pmstatus:' "$APT_STATUS" 2>/dev/null | tail -n1)
        if [[ -n $line ]]; then
            IFS=: read -r _a _b p _ <<<"$line"; pm=${p%%.*}
        fi
    fi
    [[ $dl =~ ^[0-9]+$ ]] || dl=-1
    [[ $pm =~ ^[0-9]+$ ]] || pm=-1
    if (( pm >= 0 )); then
        printf '%d' $(( 40 + pm * 60 / 100 ))
    elif (( dl >= 0 )); then
        printf '%d' $(( dl * 40 / 100 ))
    else
        printf '0'
    fi
}

probe_apt_update() {
    # apt-get update annonce un pourcentage peu fiable : on privilegie le
    # message "Retrieving file N of M" quand il est disponible.
    local line _a _b p=0 q n m f
    [[ -s $APT_STATUS ]] || { printf '0'; return; }
    line=$(grep '^dlstatus:' "$APT_STATUS" 2>/dev/null | tail -n1)
    [[ -z $line ]] && { printf '0'; return; }
    IFS=: read -r _a _b q _ <<<"$line"
    q=${q%%.*}
    [[ $q =~ ^[0-9]+$ ]] && p=$q
    if [[ $line =~ file[[:space:]]+([0-9]+)[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
        n=${BASH_REMATCH[1]}; m=${BASH_REMATCH[2]}
        if (( m > 0 )); then
            f=$(( n * 100 / m ))
            (( f > p )) && p=$f
        fi
    fi
    printf '%d' "$p"
}

probe_wget() {
    local p
    p=$(grep -o '[0-9]\{1,3\}%' "$WGET_LOG" 2>/dev/null | tail -n1)
    p=${p%\%}
    [[ $p =~ ^[0-9]+$ ]] || p=0
    if (( p == 0 )) && [[ -n $DL_TOTAL && $DL_TOTAL -gt 0 && -f $DL_FILE ]]; then
        local cur
        cur=$(stat -c %s "$DL_FILE" 2>/dev/null || echo 0)
        p=$(( cur * 100 / DL_TOTAL ))
    fi
    printf '%d' "$p"
}

#==============================================================================
#  12. MOTEUR D'EXECUTION DES ETAPES
#==============================================================================

log_line() { printf '%s\n' "$*" >>"$LOGFILE"; }

# step_run <libelle> <pct debut> <pct fin> <sonde|-> <commande...>
step_run() {
    local label=$1 ps=$2 pe=$3 probe=$4
    shift 4
    STEP_LABEL=$label
    PCT=$ps
    : >"$STEP_LOG"
    printf '\n===== %s : %s =====\n' "$(date '+%F %T')" "$label" >>"$LOGFILE"
    ( "$@" ) >>"$STEP_LOG" 2>&1 &
    local pid=$! sub rc
    while kill -0 "$pid" 2>/dev/null; do
        sub=0
        [[ $probe != "-" ]] && sub=$("$probe")
        [[ $sub =~ ^[0-9]+$ ]] || sub=0
        (( sub > 100 )) && sub=100
        PCT=$(( ps + (pe - ps) * sub / 100 ))
        anim_tick
        sleep 0.12
    done
    wait "$pid"; rc=$?
    cat "$STEP_LOG" >>"$LOGFILE" 2>/dev/null
    PCT=$pe
    anim_tick
    return $rc
}

fatal() {
    local msg=$1
    local tail_log
    tail_log=$(tail -n 6 "$STEP_LOG" 2>/dev/null | cut -c1-70)
    compute_layout
    modal_message "Echec de l'installation" \
"$msg

Dernieres lignes du journal :
${tail_log:-aucune}

Journal complet : $LOGFILE" "$C_ERR"
    tui_stop
    printf '%s\n' "ECHEC : $msg" >&2
    printf '%s\n' "Consultez $LOGFILE" >&2
    exit 1
}

#==============================================================================
#  13. TACHES D'INSTALLATION
#==============================================================================

# LC_ALL=C : les messages d'apt servent au calcul de progression,
# leur format doit rester stable quelle que soit la langue du systeme.
do_apt_update() {
    LC_ALL=C apt-get update -y -o APT::Status-Fd=3 3>"$APT_STATUS"
}

do_apt_install() {
    LC_ALL=C apt-get install -y -o APT::Status-Fd=3 "$@" 3>"$APT_STATUS"
}

do_fetch_glpi_url() {
    local url=""
    if command -v wget >/dev/null 2>&1; then
        url=$(wget -qO- --timeout=15 https://api.github.com/repos/glpi-project/glpi/releases/latest 2>/dev/null \
              | grep browser_download_url | grep -m1 'glpi-.*\.tgz' | cut -d '"' -f 4)
    fi
    if [[ -z $url ]] && command -v curl >/dev/null 2>&1; then
        url=$(curl -fsSL --max-time 15 https://api.github.com/repos/glpi-project/glpi/releases/latest 2>/dev/null \
              | grep browser_download_url | grep -m1 'glpi-.*\.tgz' | cut -d '"' -f 4)
    fi
    [[ -z $url ]] && url="$GLPI_FALLBACK_URL"
    printf '%s\n' "$url" >/tmp/glpi-url.txt
    printf 'URL retenue : %s\n' "$url"
}

do_download_glpi() {
    rm -f "$GLPI_ARCHIVE"
    : >"$WGET_LOG"
    wget --progress=dot:mega -o "$WGET_LOG" -O "$GLPI_ARCHIVE" "$GLPI_URL"
}

do_extract_glpi() {
    rm -rf "$GLPI_DIR"
    rm -rf /var/www/html/glpi-*
    mkdir -p /var/www/html
    tar -xzf "$GLPI_ARCHIVE" -C /var/www/html/
}

do_move_glpi() {
    local d
    if [[ ! -d $GLPI_DIR ]]; then
        for d in /var/www/html/glpi-*; do
            [[ -d $d ]] || continue
            mv "$d" "$GLPI_DIR"
            break
        done
    fi
    [[ -d $GLPI_DIR ]]
}

do_create_db() {
    local sql="/tmp/.glpi-db.sql" rc
    ( umask 077; : >"$sql" )
    cat >"$sql" <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS '$DB_USER'@'localhost';
DROP USER IF EXISTS '$DB_USER'@'%';
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
SQL
    mysql <"$sql"; rc=$?
    rm -f "$sql"
    return $rc
}

do_secure_mariadb() {
    local sql="/tmp/.glpi-sec.sql" rc
    ( umask 077; : >"$sql" )
    cat >"$sql" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL
    mysql <"$sql"; rc=$?
    rm -f "$sql"
    (( rc != 0 )) && return $rc
    ( umask 077; cat >"$MYSQL_CRED" <<CRED
[client]
user=root
password=$ROOT_PASS
CRED
    )
    chmod 600 "$MYSQL_CRED"
    # les tables de test sont parfois referencees dans mysql.db
    mysql --defaults-file="$MYSQL_CRED" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
    mysql --defaults-file="$MYSQL_CRED" -e "FLUSH PRIVILEGES;" 2>/dev/null
    return 0
}

do_bind_mariadb() {
    local cnf="/etc/mysql/mariadb.conf.d/50-server.cnf" addr="127.0.0.1"
    [[ $DB_REMOTE == oui ]] && addr="0.0.0.0"
    if [[ -f $cnf ]]; then
        if grep -qE '^[[:space:]]*bind-address' "$cnf"; then
            sed -i "s/^[[:space:]]*bind-address[[:space:]]*=.*/bind-address = $addr/" "$cnf"
        else
            sed -i "/^\[mysqld\]/a bind-address = $addr" "$cnf"
        fi
    fi
    systemctl restart mariadb
}

do_permissions() {
    mkdir -p "$GLPI_DATA"
    chown -R www-data:www-data "$GLPI_DIR"
    chmod -R 750 "$GLPI_DIR"
    if [[ -d $GLPI_DIR/files && ! -L $GLPI_DIR/files ]]; then
        rm -rf "$GLPI_DATA/files"
        mv "$GLPI_DIR/files" "$GLPI_DATA/"
        ln -sfn "$GLPI_DATA/files" "$GLPI_DIR/files"
    fi
    if [[ -d $GLPI_DIR/config && ! -L $GLPI_DIR/config ]]; then
        rm -rf "$GLPI_DATA/config"
        mv "$GLPI_DIR/config" "$GLPI_DATA/"
        ln -sfn "$GLPI_DATA/config" "$GLPI_DIR/config"
    fi
    mkdir -p "$GLPI_DATA/files" "$GLPI_DATA/config"
    chown -R www-data:www-data "$GLPI_DATA"
    chmod -R 770 "$GLPI_DATA"
    return 0
}

do_apache_vhost() {
    cat >/etc/apache2/sites-available/glpi.conf <<CONF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $GLPI_DIR/public
    <Directory $GLPI_DIR/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/glpi-error.log
    CustomLog \${APACHE_LOG_DIR}/glpi-access.log combined
</VirtualHost>
CONF

    if [[ $SSL_ON == oui ]]; then
        mkdir -p "$SSL_DIR"
        openssl req -x509 -nodes -days "$SSL_DAYS" -newkey rsa:2048 \
            -keyout "$SSL_DIR/glpi.key" -out "$SSL_DIR/glpi.crt" \
            -subj "/C=FR/ST=France/L=Local/O=GLPI/CN=$DOMAIN" || return 1
        chmod 600 "$SSL_DIR/glpi.key"
        cat >/etc/apache2/sites-available/glpi-ssl.conf <<CONF
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $GLPI_DIR/public
    <Directory $GLPI_DIR/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile $SSL_DIR/glpi.crt
    SSLCertificateKeyFile $SSL_DIR/glpi.key
    ErrorLog \${APACHE_LOG_DIR}/glpi-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/glpi-ssl-access.log combined
</VirtualHost>
CONF
        a2enmod ssl || return 1
        a2ensite glpi-ssl.conf || return 1
    fi

    a2enmod rewrite || return 1
    a2ensite glpi.conf || return 1
    # sans cela le site Debian par defaut repond a la place de GLPI
    a2dissite 000-default.conf 2>/dev/null
    apache2ctl configtest || return 1
    systemctl reload apache2 || systemctl restart apache2
}

do_php_config() {
    local ini
    for ini in /etc/php/*/apache2/php.ini; do
        [[ -f $ini ]] || continue
        sed -i "s/^;*[[:space:]]*session.cookie_httponly[[:space:]]*=.*/session.cookie_httponly = On/" "$ini"
        sed -i "s/^;*[[:space:]]*session.cookie_secure[[:space:]]*=.*/session.cookie_secure = On/" "$ini"
        sed -i "s/^;*[[:space:]]*intl.default_locale[[:space:]]*=.*/intl.default_locale = fr_FR/" "$ini"
        sed -i "s/^;*[[:space:]]*upload_max_filesize[[:space:]]*=.*/upload_max_filesize = 32M/" "$ini"
        sed -i "s/^;*[[:space:]]*post_max_size[[:space:]]*=.*/post_max_size = 32M/" "$ini"
        sed -i "s/^;*[[:space:]]*memory_limit[[:space:]]*=.*/memory_limit = 256M/" "$ini"
        sed -i "s/^;*[[:space:]]*max_execution_time[[:space:]]*=.*/max_execution_time = 600/" "$ini"
        sed -i "s/^;*[[:space:]]*session.cookie_samesite[[:space:]]*=.*/session.cookie_samesite = Lax/" "$ini"
    done
    systemctl reload apache2 || systemctl restart apache2
}

do_htaccess() {
    cat >"$GLPI_DIR/public/.htaccess" <<'HTA'
<IfModule mod_rewrite.c>
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

# Securite : bloquer l'acces aux fichiers sensibles
<FilesMatch "\.(htaccess|htpasswd|ini|log|sh|sql|conf|bak)$">
   Require all denied
</FilesMatch>
HTA
    local d
    for d in "$GLPI_DIR/install" "$GLPI_DIR/files" "$GLPI_DIR/config"; do
        [[ -d $d ]] || continue
        printf 'Require all denied\n' >"$d/.htaccess"
    done
    return 0
}

do_firewall() {
    command -v ufw >/dev/null 2>&1 || apt-get install -y ufw || return 1
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming || return 1
    ufw default allow outgoing || return 1
    ufw allow 22/tcp || return 1
    ufw allow 80/tcp || return 1
    ufw allow 443/tcp || return 1
    ufw --force enable
}

do_uninstaller() {
    cat >./uninstall-glpi.sh <<REMOVE
#!/bin/bash
# Desinstallation de GLPI generee par install-glpi-https.sh
export PATH=\$PATH:/usr/sbin:/sbin

echo "Suppression des fichiers GLPI..."
rm -rf "$GLPI_DIR" "$GLPI_ARCHIVE" "$GLPI_DATA"

echo "Suppression de la configuration Apache..."
rm -f /etc/apache2/sites-available/glpi.conf /etc/apache2/sites-available/glpi-ssl.conf
rm -rf "$SSL_DIR"
a2dissite glpi.conf 2>/dev/null
a2dissite glpi-ssl.conf 2>/dev/null
a2ensite 000-default.conf 2>/dev/null
systemctl reload apache2 2>/dev/null

echo "Suppression de la base de donnees..."
if [ -f "$MYSQL_CRED" ]; then
  mysql --defaults-file="$MYSQL_CRED" -e "DROP DATABASE IF EXISTS \\\`$DB_NAME\\\`;"
  mysql --defaults-file="$MYSQL_CRED" -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
  mysql --defaults-file="$MYSQL_CRED" -e "DROP USER IF EXISTS '$DB_USER'@'%';"
else
  echo "Fichier de credentials MySQL introuvable."
  echo "Supprimez manuellement la base '$DB_NAME' et l'utilisateur '$DB_USER'."
fi

echo "GLPI et ses composants ont ete supprimes."
REMOVE
    chmod +x ./uninstall-glpi.sh
}

do_cleanup_logs() {
    [[ -f $LOGFILE ]] || return 0
    [[ -n $DB_PASS ]] && sed -i "s|$DB_PASS|***MASQUE***|g" "$LOGFILE" 2>/dev/null
    [[ -n $ROOT_PASS ]] && sed -i "s|$ROOT_PASS|***MASQUE***|g" "$LOGFILE" 2>/dev/null
    rm -f /tmp/.glpi-db.sql /tmp/.glpi-sec.sql
    return 0
}

#==============================================================================
#  14. DEROULEMENT DE L'INSTALLATION
#==============================================================================

run_install() {
    DB_NAME=${VAL[db_name]}
    DB_USER=${VAL[db_user]}
    ROOT_PASS=${VAL[root_pass]}
    DB_REMOTE=${VAL[db_remote]}
    DOMAIN=${VAL[domain]}
    SSL_ON=${VAL[ssl]}
    SSL_DAYS=${VAL[ssl_days]}

    if [[ ${VAL[db_auto]} == oui ]]; then
        DB_PASS=$(openssl rand -base64 24 2>/dev/null | tr -d '=+/[:space:]' | cut -c1-16)
        [[ -z $DB_PASS ]] && DB_PASS=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-16)
        VAL[db_pass]=$DB_PASS
    else
        DB_PASS=${VAL[db_pass]}
    fi

    : >"$LOGFILE"
    chmod 600 "$LOGFILE" 2>/dev/null
    log_line "Installation GLPI demarree le $(date '+%F %T')"
    log_line "Hote: $MI_HOST  IP: $MI_IP  Domaine: $DOMAIN"

    #---------------------------------------------------------- phase 1 : DL
    anim_begin download

    step_run "Mise a jour des listes de paquets" 0 10 probe_apt_update \
        do_apt_update \
        || fatal "La mise a jour des listes de paquets a echoue."

    step_run "Installation d'Apache et MariaDB" 10 40 probe_apt \
        do_apt_install apache2 mariadb-server \
        || fatal "L'installation du serveur web ou de MariaDB a echoue."

    step_run "Installation de PHP et de ses extensions" 40 70 probe_apt \
        do_apt_install php php-mysql php-xml php-mbstring php-curl php-gd php-intl \
                       php-ldap php-imap php-zip php-bz2 php-cli php-apcu php-bcmath \
                       php-opcache php-exif libapache2-mod-php \
        || fatal "L'installation de PHP a echoue."

    step_run "Installation des utilitaires" 70 78 probe_apt \
        do_apt_install unzip wget tar curl openssl ca-certificates \
        || fatal "L'installation des utilitaires a echoue."

    step_run "Recherche de la derniere version de GLPI" 78 82 - \
        do_fetch_glpi_url \
        || fatal "Impossible de determiner la version de GLPI a telecharger."

    GLPI_URL=$(cat /tmp/glpi-url.txt 2>/dev/null)
    [[ -z $GLPI_URL ]] && GLPI_URL="$GLPI_FALLBACK_URL"
    log_line "Archive: $GLPI_URL"

    STEP_LABEL="Preparation du telechargement"
    anim_tick
    DL_FILE="$GLPI_ARCHIVE"
    DL_TOTAL=$(wget --spider -S "$GLPI_URL" 2>&1 | awk '/[Cc]ontent-[Ll]ength:/ {print $2}' | tail -n1 | tr -d '\r')
    [[ $DL_TOTAL =~ ^[0-9]+$ ]] || DL_TOTAL=0

    step_run "Telechargement de l'archive GLPI" 82 100 probe_wget \
        do_download_glpi \
        || fatal "Le telechargement de GLPI a echoue."

    DL_FILE=""
    sleep 0.4

    #------------------------------------------------------ phase 2 : INSTALL
    anim_begin install

    step_run "Extraction de l'archive" 0 14 - \
        do_extract_glpi \
        || fatal "L'extraction de l'archive GLPI a echoue."

    step_run "Mise en place des fichiers" 14 20 - \
        do_move_glpi \
        || fatal "Le repertoire GLPI n'a pas pu etre cree."

    step_run "Creation de la base de donnees" 20 30 - \
        do_create_db \
        || fatal "La creation de la base de donnees a echoue."

    step_run "Securisation de MariaDB" 30 40 - \
        do_secure_mariadb \
        || fatal "La securisation de MariaDB a echoue."

    step_run "Configuration de l'ecoute MariaDB" 40 48 - \
        do_bind_mariadb \
        || fatal "Le redemarrage de MariaDB a echoue."

    step_run "Permissions et repertoires proteges" 48 58 - \
        do_permissions \
        || fatal "L'application des permissions a echoue."

    step_run "Configuration d'Apache et du certificat" 58 72 - \
        do_apache_vhost \
        || fatal "La configuration d'Apache a echoue."

    step_run "Configuration de PHP" 72 78 - \
        do_php_config \
        || fatal "La configuration de PHP a echoue."

    step_run "Protection des repertoires sensibles" 78 84 - \
        do_htaccess \
        || fatal "L'ecriture des fichiers .htaccess a echoue."

    if [[ ${VAL[firewall]} == oui ]]; then
        step_run "Configuration du pare-feu UFW" 84 92 - \
            do_firewall \
            || fatal "La configuration du pare-feu a echoue."
    else
        PCT=92; STEP_LABEL="Pare-feu ignore"; anim_tick
    fi

    if [[ ${VAL[uninstaller]} == oui ]]; then
        step_run "Generation du script de desinstallation" 92 96 - \
            do_uninstaller \
            || fatal "La generation du script de desinstallation a echoue."
    fi

    step_run "Nettoyage" 96 100 - do_cleanup_logs

    STEP_LABEL="Termine"
    PCT=100
    anim_tick
    sleep 0.6
}

#==============================================================================
#  15. ECRAN FINAL
#==============================================================================

run_tests() {
    TEST_APACHE="Apache : arrete"
    TEST_MDB="MariaDB : arrete"
    TEST_DIR="Repertoire GLPI : absent"
    systemctl is-active --quiet apache2 && TEST_APACHE="Apache : actif"
    systemctl is-active --quiet mariadb && TEST_MDB="MariaDB : actif"
    [[ -d $GLPI_DIR ]] && TEST_DIR="Repertoire GLPI : present"
}

final_screen() {
    local proto="http" port=""
    [[ $SSL_ON == oui ]] && proto="https"
    local url="$proto://$DOMAIN/"

    local tests=""
    if [[ ${VAL[tests]} == oui ]]; then
        run_tests
        tests="

Verifications :
  $TEST_APACHE
  $TEST_MDB
  $TEST_DIR"
    fi

    local uninst=""
    [[ ${VAL[uninstaller]} == oui ]] && uninst="

Desinstallation : ./uninstall-glpi.sh"

    RECAP="Installation terminee.

Acces GLPI      : $url
Adresse IP      : $MI_IP

Base de donnees : $DB_NAME
Utilisateur     : $DB_USER
Mot de passe    : $DB_PASS
Root MariaDB    : enregistre dans $MYSQL_CRED

Identifiants GLPI par defaut : glpi / glpi
ATTENTION : changez-les des la premiere connexion
et supprimez le repertoire $GLPI_DIR/install
une fois l'assistant web termine.$tests$uninst

Journal : $LOGFILE"

    compute_layout
    BUF=$'\e[2J'
    local w=$(( COLS - 8 ))
    (( w > 76 )) && w=76
    local -a lines
    local l
    while IFS= read -r l; do lines+=("$l"); done <<<"$RECAP"
    local h=$(( ${#lines[@]} + 4 ))
    (( h > ROWS - 2 )) && h=$(( ROWS - 2 ))
    local y=$(( (ROWS - h) / 2 )) x=$(( (COLS - w) / 2 ))
    (( y < 1 )) && y=1
    (( x < 1 )) && x=1
    draw_box "$y" "$x" "$h" "$w" "GLPI - INSTALLATION TERMINEE" "$C_FRAME_ON"
    local i c
    for (( i = 0; i < ${#lines[@]} && i < h - 4; i++ )); do
        c=$C_VALUE
        [[ ${lines[i]} == ATTENTION* ]] && c=$C_WARN
        [[ ${lines[i]} == "Installation terminee."* ]] && c=$C_OK
        pad_str "${lines[i]}" $(( w - 4 ))
        put $(( y + 1 + i )) $(( x + 2 )) "${c}${PAD}${C_RESET}"
    done
    pad_str "Appuyez sur une touche pour quitter" $(( w - 4 ))
    put $(( y + h - 2 )) $(( x + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    wait_key
}

#==============================================================================
#  16. VERIFICATIONS PREALABLES
#==============================================================================

precheck() {
    if [[ $EUID -ne 0 ]]; then
        printf 'Ce script doit etre execute avec sudo ou en tant que root.\n' >&2
        exit 1
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        printf "Ce script necessite un terminal interactif.\n" >&2
        exit 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        printf 'Systeme non supporte : apt-get est introuvable (Debian 12 attendu).\n' >&2
        exit 1
    fi
    touch "$LOGFILE" 2>/dev/null || LOGFILE="/tmp/glpi-install.log"
}

check_internet() {
    if command -v wget >/dev/null 2>&1; then
        wget -q --spider --timeout=8 https://github.com && return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 8 -o /dev/null https://github.com && return 0
    fi
    ( exec 3<>/dev/tcp/1.1.1.1/443 ) 2>/dev/null && return 0
    return 1
}

#==============================================================================
#  17. BOUCLE PRINCIPALE
#==============================================================================

cleanup() {
    tui_stop
    rm -f "$STEP_LOG" "$APT_STATUS" /tmp/glpi-url.txt /tmp/.glpi-db.sql /tmp/.glpi-sec.sql 2>/dev/null
}

main_loop() {
    local n idx dead=0
    while :; do
        build_rows
        n=${#VR_TYPE[@]}
        (( SEL > n )) && SEL=$n
        (( SEL < 0 )) && SEL=0
        [[ ${VR_TYPE[$SEL]:-} == gap ]] && move_sel 1
        adjust_scroll
        render_main
        read_key
        (( RESIZED )) && { compute_layout; RESIZED=0; STATUS_MSG=""; STATUS_KIND="info"; dead=0; continue; }
        if [[ $KEY == "NONE" ]]; then
            # entree standard perdue (terminal ferme) : on evite la boucle folle
            dead=$(( dead + 1 ))
            (( dead > 200 )) && return 1
            continue
        fi
        dead=0
        STATUS_MSG=""
        STATUS_KIND="info"
        idx=${VR_IDX[$SEL]:--1}
        case $KEY in
            UP|"CHAR:k")   move_sel -1 ;;
            DOWN|"CHAR:j"|TAB) move_sel 1 ;;
            PGUP) SEL=$(( SEL - FORM_ROWS )); (( SEL < 0 )) && SEL=0 ;;
            PGDN) SEL=$(( SEL + FORM_ROWS )); (( SEL > n )) && SEL=$n ;;
            HOME) SEL=0 ;;
            END)  SEL=$n ;;
            LEFT|RIGHT|"CHAR:h"|"CHAR:l")
                if sel_is_button; then
                    :
                elif [[ ${VR_TYPE[$SEL]} == sec ]]; then
                    if [[ $KEY == LEFT || $KEY == "CHAR:h" ]]; then SEC_OPEN[idx]=0; else SEC_OPEN[idx]=1; fi
                elif [[ ${FLD_TYPE[$idx]} == bool ]]; then
                    toggle_bool "${FLD_KEY[$idx]}"
                fi
                ;;
            SPACE)
                if ! sel_is_button && [[ ${VR_TYPE[$SEL]} == fld && ${FLD_TYPE[$idx]} == bool ]]; then
                    toggle_bool "${FLD_KEY[$idx]}"
                elif ! sel_is_button && [[ ${VR_TYPE[$SEL]} == sec ]]; then
                    SEC_OPEN[idx]=$(( 1 - SEC_OPEN[idx] ))
                fi
                ;;
            ENTER)
                if sel_is_button; then
                    if validate_form; then
                        local extra=""
                        [[ -d $GLPI_DIR ]] && extra="
ATTENTION : $GLPI_DIR existe deja
et sera entierement supprime puis recree.
"
                        if modal_confirm "Confirmation" \
"L'installation de GLPI va demarrer.

Les paquets Apache, MariaDB et PHP seront
installes et la configuration du serveur
sera modifiee.
$extra
Lancer l'installation ?"; then
                            return 0
                        fi
                    else
                        modal_message "Configuration incomplete" "$FERR" "$C_ERR"
                        select_field_row "$FKEY"
                    fi
                elif [[ ${VR_TYPE[$SEL]} == sec ]]; then
                    SEC_OPEN[idx]=$(( 1 - SEC_OPEN[idx] ))
                else
                    edit_field "$idx"
                fi
                ;;
            "CHAR:t"|"CHAR:T")
                toggle_theme
                if [[ $THEME == light ]]; then
                    STATUS_MSG="Theme clair active (touche t pour revenir au theme sombre)."
                else
                    STATUS_MSG="Theme sombre active (touche t pour passer au theme clair)."
                fi
                STATUS_KIND="ok"
                ;;
            "CHAR:r"|"CHAR:R")
                STATUS_MSG="Actualisation des informations machine..."
                STATUS_KIND="info"
                render_main
                collect_machine_info
                STATUS_MSG="Informations machine actualisees."
                STATUS_KIND="ok"
                ;;
            "CHAR:q"|"CHAR:Q"|ESC)
                if modal_confirm "Quitter" "Quitter sans installer GLPI ?"; then
                    return 1
                fi
                ;;
        esac
    done
}

main() {
    setup_locale
    setup_charset
    setup_colors
    precheck
    load_tux
    build_form

    trap cleanup EXIT
    trap 'cleanup; exit 130' INT TERM
    trap on_resize WINCH

    compute_layout
    tui_start

    # la couleur de fond est demandee une fois l'ecran alternatif actif :
    # une eventuelle reponse non consommee reste invisible pour l'utilisateur
    detect_theme
    setup_colors

    collect_machine_info
    VAL[domain]="$MI_IP"

    if term_too_small; then
        render_main
        wait_key
        cleanup
        printf 'Agrandissez la fenetre du terminal (minimum 74x20) puis relancez le script.\n' >&2
        exit 1
    fi

    if ! check_internet; then
        modal_message "Pas de connexion Internet" \
$'Impossible de joindre Internet.\n\nUne connexion est necessaire pour telecharger\nles paquets et l\'archive GLPI.' "$C_ERR"
    fi

    if ! main_loop; then
        cleanup
        printf 'Installation annulee par l\047utilisateur.\n'
        exit 0
    fi

    run_install
    final_screen

    cleanup
    trap - EXIT
    printf '%s\n' "$RECAP"
}

main "$@"
