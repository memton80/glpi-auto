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
#  Auteur : memton80
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
    # 11 lignes : panneau machine detaille (9 informations)
    # 8 lignes  : version compacte, pour garder tous les raccourcis visibles
    MACH_H=11
    HELP_H=$(( BODY_H - MACH_H ))
    if (( HELP_H < 9 )); then
        MACH_H=8
        HELP_H=$(( BODY_H - MACH_H ))
    fi
    (( HELP_H < 3 )) && { MACH_H=$(( BODY_H - 3 )); HELP_H=3; }

    FORM_ROWS=$(( BODY_H - 2 ))
}

term_too_small() { (( COLS < 74 || ROWS < 20 )); }

#==============================================================================
#  2. TRADUCTIONS
#
#  Toutes les chaines affichees sont chargees dans des variables L_* par
#  load_strings(), appelee une fois la langue choisie. Les deux blocs se
#  suivent dans le meme ordre pour rester faciles a comparer.
#==============================================================================

UILANG="fr"
declare -a L_KEYS

load_strings() {
    if [[ $UILANG == en ]]; then
        # ---------------------------------------------------------- ENGLISH
        L_APP_TITLE="GLPI AUTO - DEBIAN 12 INSTALLER"
        L_PANEL_CONFIG="Configuration"
        L_PANEL_MACHINE="Machine"
        L_PANEL_KEYS="Shortcuts"
        L_BTN_INSTALL="[ INSTALL ]"
        L_KEYS=(
            "Up/Down|move"
            "Enter|edit / confirm"
            "Space|yes / no"
            "Left/Right|fold / unfold"
            "r|refresh machine"
            "t|light/dark theme"
            "q|quit"
        )
        L_NOTE_TARGET="Installed into"
        L_NOTE_LOG="Log file"

        # panneau machine
        L_M_HOST="Hostname"
        L_M_IP="IP address"
        L_M_OS="System"
        L_M_CPU="CPU"
        L_M_RAM="Memory"
        L_M_DISK="Disk /var"
        L_M_FW="Firewall"
        L_M_P80="Port 80"
        L_M_P443="Port 443"
        L_M_CPURAM="CPU / RAM"
        L_M_PORTS="Web ports"
        L_V_FREE="free"
        L_V_BUSY="in use"
        L_V_UNKNOWN="unknown"
        L_V_UNKNOWN_F="unknown"
        L_V_ACTIVE="active"
        L_V_INACTIVE="inactive"
        L_V_NONE="none"
        L_V_CORE="core"
        L_V_CORES="cores"
        L_V_SPACE_FREE="free"
        L_V_SPACE_FREE_P="free"
        L_U_GB="GB"; L_U_MB="MB"; L_U_KB="KB"; L_U_B="B"
        L_DECIMAL="."

        # formulaire
        L_SEC_DB="Database"
        L_SEC_SECURITY="Security"
        L_SEC_WEB="Web and HTTPS"
        L_SEC_OPTIONS="Options"
        L_F_DBNAME="Database name"
        L_H_DBNAME="Letters, digits and underscore only."
        L_F_DBUSER="MySQL user"
        L_H_DBUSER="Letters, digits and underscore only."
        L_F_DBAUTO="Generate the password"
        L_H_DBAUTO="Generates a strong 16 character password."
        L_F_DBPASS="MySQL password"
        L_H_DBPASS="8 characters minimum, no space and no quote."
        L_F_ROOTPASS="MariaDB root password"
        L_H_ROOTPASS="Required. Saved into %s."
        L_F_REMOTE="Remote MariaDB access"
        L_H_REMOTE="Makes MariaDB listen on 0.0.0.0: only with a firewall."
        L_F_FIREWALL="Configure the UFW firewall"
        L_H_FIREWALL="Allows ports 22 (SSH), 80 and 443 only."
        L_F_DOMAIN="Server domain or IP"
        L_H_DOMAIN="Used for the certificate and the final URL."
        L_F_SSL="Self-signed certificate"
        L_H_SSL="Creates a self-signed HTTPS certificate for the domain."
        L_F_SSLDAYS="Certificate validity (days)"
        L_H_SSLDAYS="Number of days the certificate stays valid (1 to 3650)."
        L_F_UNINSTALL="Uninstall script"
        L_H_UNINSTALL="Generates ./uninstall-glpi.sh at the end."
        L_F_TESTS="Verification tests"
        L_H_TESTS="Checks Apache, MariaDB and the GLPI directory."

        # barre de statut
        L_ST_BUTTON="Press Enter to start the GLPI installation."
        L_ST_SECTION="Enter or Left/Right to fold or unfold the section."
        L_ST_THEME_LIGHT="Light theme enabled (press t for the dark theme)."
        L_ST_THEME_DARK="Dark theme enabled (press t for the light theme)."
        L_ST_REFRESHING="Refreshing machine information..."
        L_ST_REFRESHED="Machine information refreshed."

        # modales
        L_ANY_KEY="Press any key to continue"
        L_ANY_KEY_QUIT="Press any key to quit"
        L_YES="[ Yes ]"
        L_NO="[ No ]"
        L_YESV="yes"
        L_NOV="no"
        L_UNSET="not set"
        L_EMPTY="empty"
        L_EDIT_HELP="Enter: confirm     Esc: cancel"
        L_PASS_CONFIRM="Confirm the password:"
        L_PASS_RETYPE="Type the same value again."
        L_PASS_MISMATCH_T="Passwords do not match"
        L_PASS_MISMATCH=$'The two entries do not match.\nPlease try again.'
        L_INVALID_T="Invalid value"

        # validation
        L_ERR_IDENT="Only letters, digits and underscore are allowed."
        L_ERR_PASS_SHORT="The password must be at least 8 characters long."
        L_ERR_PASS_CHARS="Forbidden characters: space, quote, double quote, backslash, backtick."
        L_ERR_HOST="Invalid domain name or IP address."
        L_ERR_DAYS_NUM="Enter a number of days."
        L_ERR_DAYS_RANGE="The validity must be between 1 and 3650 days."
        L_FORM_INCOMPLETE_T="Incomplete configuration"

        # confirmation et sortie
        L_CONFIRM_T="Confirmation"
        L_CONFIRM_BODY=$'The GLPI installation is about to start.\n\nApache, MariaDB and PHP will be installed\nand the server configuration will be changed.'
        L_CONFIRM_EXISTS=$'WARNING: %s already exists\nand will be entirely removed and recreated.'
        L_CONFIRM_HW="WARNING: undersized hardware"
        L_CONFIRM_ASK="Start the installation?"
        L_QUIT_T="Quit"
        L_QUIT_ASK="Quit without installing GLPI?"
        L_CANCELLED="Installation cancelled by the user."
        L_NET_T="No Internet connection"
        L_NET_BODY=$'Internet cannot be reached.\n\nA connection is required to download the\npackages and the GLPI archive.'
        L_TOO_SMALL="Terminal too small: %sx%s. Minimum required 74x20."
        L_TOO_SMALL_CLI="Enlarge the terminal window (minimum 74x20) then run the script again."

        # materiel
        L_HW_T="Undersized hardware"
        L_HW_HEAD="This machine is undersized."
        L_HW_HEAD_CRIT="This machine is severely undersized."
        L_HW_CONSEQ=$'The installation is still possible, but GLPI\nis likely to be slow under load.'
        L_HW_CONSEQ_CRIT=$'The installation may fail for lack of resources,\nor leave a GLPI unusable in production.'
        L_HW_CONTINUE="You can proceed anyway."
        L_HW_L_CPU="CPU"
        L_HW_L_RAM="Memory"
        L_HW_L_DISK="Disk /var"
        L_HW_RECO_CPU="%s cores recommended"
        L_HW_RECO="%s recommended"
        L_HW_INSUF="insufficient"
        L_HW_INSUF_F="insufficient"
        L_HW_SHORT_CPU="CPU"
        L_HW_SHORT_RAM="memory"
        L_HW_SHORT_DISK="disk"

        # ecrans d'installation
        L_ANIM_DL_TITLE="DOWNLOADING COMPONENTS"
        L_ANIM_INST_TITLE="INSTALLATION"
        L_ANIM_DL_PHASE="DOWNLOAD IN PROGRESS"
        L_ANIM_INST_PHASE="INSTALLATION IN PROGRESS"
        L_ANIM_LOG="Full log: %s"
        L_DL_RECEIVED="%s received"

        # etapes
        L_S_APT_UPDATE="Updating package lists"
        L_S_APT_WEB="Installing Apache and MariaDB"
        L_S_APT_PHP="Installing PHP and its extensions"
        L_S_APT_TOOLS="Installing utilities"
        L_S_FETCH="Looking for the latest GLPI release"
        L_S_PREPARE_DL="Preparing the download"
        L_S_DOWNLOAD="Downloading the GLPI archive"
        L_S_EXTRACT="Extracting the archive"
        L_S_MOVE="Setting up the files"
        L_S_CREATE_DB="Creating the database"
        L_S_SECURE_DB="Hardening MariaDB"
        L_S_BIND_DB="Configuring the MariaDB listener"
        L_S_PERMS="Permissions and protected directories"
        L_S_APACHE="Configuring Apache and the certificate"
        L_S_PHP="Configuring PHP"
        L_S_HTACCESS="Protecting sensitive directories"
        L_S_FIREWALL="Configuring the UFW firewall"
        L_S_FIREWALL_SKIP="Firewall skipped"
        L_S_UNINSTALL="Generating the uninstall script"
        L_S_CLEANUP="Cleaning up"
        L_S_DONE="Done"

        # erreurs d'etape
        L_E_APT_UPDATE="Updating the package lists failed."
        L_E_APT_WEB="Installing the web server or MariaDB failed."
        L_E_APT_PHP="Installing PHP failed."
        L_E_APT_TOOLS="Installing the utilities failed."
        L_E_FETCH="The GLPI version to download could not be determined."
        L_E_DOWNLOAD="Downloading GLPI failed."
        L_E_EXTRACT="Extracting the GLPI archive failed."
        L_E_MOVE="The GLPI directory could not be created."
        L_E_CREATE_DB="Creating the database failed."
        L_E_SECURE_DB="Hardening MariaDB failed."
        L_E_BIND_DB="Restarting MariaDB failed."
        L_E_PERMS="Applying the permissions failed."
        L_E_APACHE="Configuring Apache failed."
        L_E_PHP="Configuring PHP failed."
        L_E_HTACCESS="Writing the .htaccess files failed."
        L_E_FIREWALL="Configuring the firewall failed."
        L_E_UNINSTALL="Generating the uninstall script failed."

        # echec
        L_FATAL_T="Installation failed"
        L_FATAL_LOGTAIL="Last lines of the log:"
        L_FATAL_NONE="none"
        L_FATAL_LOG="Full log: %s"
        L_FATAL_CLI="FAILED: %s"
        L_FATAL_CLI2="See %s"

        # tests et recapitulatif
        L_TEST_HEAD="Checks:"
        L_TEST_APACHE_UP="Apache: running"
        L_TEST_APACHE_DOWN="Apache: stopped"
        L_TEST_MDB_UP="MariaDB: running"
        L_TEST_MDB_DOWN="MariaDB: stopped"
        L_TEST_DIR_OK="GLPI directory: present"
        L_TEST_DIR_KO="GLPI directory: missing"
        L_FINAL_T="GLPI - INSTALLATION COMPLETE"
        L_FINAL_DONE="Installation complete."
        L_FINAL_URL="GLPI address"
        L_FINAL_IP="IP address"
        L_FINAL_DB="Database"
        L_FINAL_USER="User"
        L_FINAL_PASS="Password"
        L_FINAL_ROOT="MariaDB root"
        L_FINAL_ROOT_V="saved into %s"
        L_FINAL_DEFAULT="Default GLPI credentials: glpi / glpi"
        L_FINAL_WARN=$'WARNING: change them at the first login\nand delete the %s directory\nonce the web wizard is finished.'
        L_FINAL_UNINSTALL="Uninstall: ./uninstall-glpi.sh"
        L_FINAL_LOG="Log file"

        # script de desinstallation
        L_UN_HEAD="GLPI uninstaller generated by install-glpi-https.sh"
        L_UN_FILES="Removing the GLPI files..."
        L_UN_APACHE="Removing the Apache configuration..."
        L_UN_DB="Removing the database..."
        L_UN_NOCRED="MySQL credentials file not found."
        L_UN_MANUAL="Manually drop the database '%s' and the user '%s'."
        L_UN_DONE="GLPI and its components have been removed."
    else
        # --------------------------------------------------------- FRANCAIS
        L_APP_TITLE="GLPI AUTO - INSTALLATEUR DEBIAN 12"
        L_PANEL_CONFIG="Configuration"
        L_PANEL_MACHINE="Machine"
        L_PANEL_KEYS="Raccourcis"
        L_BTN_INSTALL="[ INSTALLER ]"
        L_KEYS=(
            "Haut/Bas|deplacer"
            "Entree|modifier / valider"
            "Espace|oui / non"
            "Gauche/Droite|plier / deplier"
            "r|infos machine"
            "t|theme clair/sombre"
            "q|quitter"
        )
        L_NOTE_TARGET="Installation dans"
        L_NOTE_LOG="Journal"

        # panneau machine
        L_M_HOST="Nom d'hote"
        L_M_IP="Adresse IP"
        L_M_OS="Systeme"
        L_M_CPU="Processeur"
        L_M_RAM="Memoire"
        L_M_DISK="Disque /var"
        L_M_FW="Pare-feu"
        L_M_P80="Port 80"
        L_M_P443="Port 443"
        L_M_CPURAM="CPU / RAM"
        L_M_PORTS="Ports web"
        L_V_FREE="libre"
        L_V_BUSY="occupe"
        L_V_UNKNOWN="inconnu"
        L_V_UNKNOWN_F="inconnue"
        L_V_ACTIVE="actif"
        L_V_INACTIVE="inactif"
        L_V_NONE="aucun"
        L_V_CORE="coeur"
        L_V_CORES="coeurs"
        L_V_SPACE_FREE="libre"
        L_V_SPACE_FREE_P="libres"
        L_U_GB="Go"; L_U_MB="Mo"; L_U_KB="Ko"; L_U_B="o"
        L_DECIMAL=","

        # formulaire
        L_SEC_DB="Base de donnees"
        L_SEC_SECURITY="Securite"
        L_SEC_WEB="Web et HTTPS"
        L_SEC_OPTIONS="Options"
        L_F_DBNAME="Nom de la base"
        L_H_DBNAME="Lettres, chiffres et tiret bas uniquement."
        L_F_DBUSER="Utilisateur MySQL"
        L_H_DBUSER="Lettres, chiffres et tiret bas uniquement."
        L_F_DBAUTO="Generer le mot de passe"
        L_H_DBAUTO="Genere un mot de passe fort de 16 caracteres."
        L_F_DBPASS="Mot de passe MySQL"
        L_H_DBPASS="8 caracteres minimum, sans espace ni quote."
        L_F_ROOTPASS="Mot de passe root MariaDB"
        L_H_ROOTPASS="Obligatoire. Sauvegarde dans %s."
        L_F_REMOTE="Acces MariaDB distant"
        L_H_REMOTE="Fait ecouter MariaDB sur 0.0.0.0 : a n'activer qu'avec un pare-feu."
        L_F_FIREWALL="Configurer le pare-feu UFW"
        L_H_FIREWALL="N'autorise que les ports 22 (SSH), 80 et 443."
        L_F_DOMAIN="Domaine ou IP du serveur"
        L_H_DOMAIN="Utilise pour le certificat et l'URL finale."
        L_F_SSL="Certificat auto-signe"
        L_H_SSL="Cree un certificat HTTPS auto-signe pour le domaine."
        L_F_SSLDAYS="Duree du certificat (j)"
        L_H_SSLDAYS="Nombre de jours de validite (1 a 3650)."
        L_F_UNINSTALL="Script de desinstallation"
        L_H_UNINSTALL="Genere ./uninstall-glpi.sh a la fin."
        L_F_TESTS="Tests de verification"
        L_H_TESTS="Verifie Apache, MariaDB et le repertoire GLPI."

        # barre de statut
        L_ST_BUTTON="Entree pour lancer l'installation de GLPI."
        L_ST_SECTION="Entree ou Gauche/Droite pour plier ou deplier la section."
        L_ST_THEME_LIGHT="Theme clair active (touche t pour revenir au theme sombre)."
        L_ST_THEME_DARK="Theme sombre active (touche t pour passer au theme clair)."
        L_ST_REFRESHING="Actualisation des informations machine..."
        L_ST_REFRESHED="Informations machine actualisees."

        # modales
        L_ANY_KEY="Appuyez sur une touche pour continuer"
        L_ANY_KEY_QUIT="Appuyez sur une touche pour quitter"
        L_YES="[ Oui ]"
        L_NO="[ Non ]"
        L_YESV="oui"
        L_NOV="non"
        L_UNSET="non defini"
        L_EMPTY="vide"
        L_EDIT_HELP="Entree : valider     Echap : annuler"
        L_PASS_CONFIRM="Confirmez le mot de passe :"
        L_PASS_RETYPE="Ressaisissez la meme valeur."
        L_PASS_MISMATCH_T="Mots de passe differents"
        L_PASS_MISMATCH=$'Les deux saisies ne correspondent pas.\nVeuillez recommencer.'
        L_INVALID_T="Valeur invalide"

        # validation
        L_ERR_IDENT="Seuls les lettres, chiffres et le tiret bas sont autorises."
        L_ERR_PASS_SHORT="Le mot de passe doit faire au moins 8 caracteres."
        L_ERR_PASS_CHARS="Caracteres interdits : espace, quote, double quote, antislash, accent grave."
        L_ERR_HOST="Domaine ou adresse IP invalide."
        L_ERR_DAYS_NUM="Saisissez un nombre de jours."
        L_ERR_DAYS_RANGE="La duree doit etre comprise entre 1 et 3650 jours."
        L_FORM_INCOMPLETE_T="Configuration incomplete"

        # confirmation et sortie
        L_CONFIRM_T="Confirmation"
        L_CONFIRM_BODY=$'L\'installation de GLPI va demarrer.\n\nLes paquets Apache, MariaDB et PHP seront\ninstalles et la configuration du serveur\nsera modifiee.'
        L_CONFIRM_EXISTS=$'ATTENTION : %s existe deja\net sera entierement supprime puis recree.'
        L_CONFIRM_HW="ATTENTION : materiel sous-dimensionne"
        L_CONFIRM_ASK="Lancer l'installation ?"
        L_QUIT_T="Quitter"
        L_QUIT_ASK="Quitter sans installer GLPI ?"
        L_CANCELLED="Installation annulee par l'utilisateur."
        L_NET_T="Pas de connexion Internet"
        L_NET_BODY=$'Impossible de joindre Internet.\n\nUne connexion est necessaire pour telecharger\nles paquets et l\'archive GLPI.'
        L_TOO_SMALL="Terminal trop petit : %sx%s. Minimum requis 74x20."
        L_TOO_SMALL_CLI="Agrandissez la fenetre du terminal (minimum 74x20) puis relancez le script."

        # materiel
        L_HW_T="Materiel sous-dimensionne"
        L_HW_HEAD="Le materiel de cette machine est sous-dimensionne."
        L_HW_HEAD_CRIT="Le materiel de cette machine est nettement sous-dimensionne."
        L_HW_CONSEQ=$'L\'installation reste possible, mais GLPI risque\nd\'etre lent sous charge.'
        L_HW_CONSEQ_CRIT=$'L\'installation peut echouer par manque de ressources,\nou laisser un GLPI inutilisable en production.'
        L_HW_CONTINUE="Vous pouvez continuer malgre tout."
        L_HW_L_CPU="Processeur"
        L_HW_L_RAM="Memoire vive"
        L_HW_L_DISK="Disque /var"
        L_HW_RECO_CPU="%s coeurs recommandes"
        L_HW_RECO="%s recommandes"
        L_HW_INSUF="insuffisant"
        L_HW_INSUF_F="insuffisante"
        L_HW_SHORT_CPU="processeur"
        L_HW_SHORT_RAM="memoire"
        L_HW_SHORT_DISK="disque"

        # ecrans d'installation
        L_ANIM_DL_TITLE="TELECHARGEMENT DES COMPOSANTS"
        L_ANIM_INST_TITLE="INSTALLATION"
        L_ANIM_DL_PHASE="TELECHARGEMENT EN COURS"
        L_ANIM_INST_PHASE="INSTALLATION EN COURS"
        L_ANIM_LOG="Journal complet : %s"
        L_DL_RECEIVED="%s recus"

        # etapes
        L_S_APT_UPDATE="Mise a jour des listes de paquets"
        L_S_APT_WEB="Installation d'Apache et MariaDB"
        L_S_APT_PHP="Installation de PHP et de ses extensions"
        L_S_APT_TOOLS="Installation des utilitaires"
        L_S_FETCH="Recherche de la derniere version de GLPI"
        L_S_PREPARE_DL="Preparation du telechargement"
        L_S_DOWNLOAD="Telechargement de l'archive GLPI"
        L_S_EXTRACT="Extraction de l'archive"
        L_S_MOVE="Mise en place des fichiers"
        L_S_CREATE_DB="Creation de la base de donnees"
        L_S_SECURE_DB="Securisation de MariaDB"
        L_S_BIND_DB="Configuration de l'ecoute MariaDB"
        L_S_PERMS="Permissions et repertoires proteges"
        L_S_APACHE="Configuration d'Apache et du certificat"
        L_S_PHP="Configuration de PHP"
        L_S_HTACCESS="Protection des repertoires sensibles"
        L_S_FIREWALL="Configuration du pare-feu UFW"
        L_S_FIREWALL_SKIP="Pare-feu ignore"
        L_S_UNINSTALL="Generation du script de desinstallation"
        L_S_CLEANUP="Nettoyage"
        L_S_DONE="Termine"

        # erreurs d'etape
        L_E_APT_UPDATE="La mise a jour des listes de paquets a echoue."
        L_E_APT_WEB="L'installation du serveur web ou de MariaDB a echoue."
        L_E_APT_PHP="L'installation de PHP a echoue."
        L_E_APT_TOOLS="L'installation des utilitaires a echoue."
        L_E_FETCH="Impossible de determiner la version de GLPI a telecharger."
        L_E_DOWNLOAD="Le telechargement de GLPI a echoue."
        L_E_EXTRACT="L'extraction de l'archive GLPI a echoue."
        L_E_MOVE="Le repertoire GLPI n'a pas pu etre cree."
        L_E_CREATE_DB="La creation de la base de donnees a echoue."
        L_E_SECURE_DB="La securisation de MariaDB a echoue."
        L_E_BIND_DB="Le redemarrage de MariaDB a echoue."
        L_E_PERMS="L'application des permissions a echoue."
        L_E_APACHE="La configuration d'Apache a echoue."
        L_E_PHP="La configuration de PHP a echoue."
        L_E_HTACCESS="L'ecriture des fichiers .htaccess a echoue."
        L_E_FIREWALL="La configuration du pare-feu a echoue."
        L_E_UNINSTALL="La generation du script de desinstallation a echoue."

        # echec
        L_FATAL_T="Echec de l'installation"
        L_FATAL_LOGTAIL="Dernieres lignes du journal :"
        L_FATAL_NONE="aucune"
        L_FATAL_LOG="Journal complet : %s"
        L_FATAL_CLI="ECHEC : %s"
        L_FATAL_CLI2="Consultez %s"

        # tests et recapitulatif
        L_TEST_HEAD="Verifications :"
        L_TEST_APACHE_UP="Apache : actif"
        L_TEST_APACHE_DOWN="Apache : arrete"
        L_TEST_MDB_UP="MariaDB : actif"
        L_TEST_MDB_DOWN="MariaDB : arrete"
        L_TEST_DIR_OK="Repertoire GLPI : present"
        L_TEST_DIR_KO="Repertoire GLPI : absent"
        L_FINAL_T="GLPI - INSTALLATION TERMINEE"
        L_FINAL_DONE="Installation terminee."
        L_FINAL_URL="Acces GLPI"
        L_FINAL_IP="Adresse IP"
        L_FINAL_DB="Base de donnees"
        L_FINAL_USER="Utilisateur"
        L_FINAL_PASS="Mot de passe"
        L_FINAL_ROOT="Root MariaDB"
        L_FINAL_ROOT_V="enregistre dans %s"
        L_FINAL_DEFAULT="Identifiants GLPI par defaut : glpi / glpi"
        L_FINAL_WARN=$'ATTENTION : changez-les des la premiere connexion\net supprimez le repertoire %s\nune fois l\'assistant web termine.'
        L_FINAL_UNINSTALL="Desinstallation : ./uninstall-glpi.sh"
        L_FINAL_LOG="Journal"

        # script de desinstallation
        L_UN_HEAD="Desinstallation de GLPI generee par install-glpi-https.sh"
        L_UN_FILES="Suppression des fichiers GLPI..."
        L_UN_APACHE="Suppression de la configuration Apache..."
        L_UN_DB="Suppression de la base de donnees..."
        L_UN_NOCRED="Fichier de credentials MySQL introuvable."
        L_UN_MANUAL="Supprimez manuellement la base '%s' et l'utilisateur '%s'."
        L_UN_DONE="GLPI et ses composants ont ete supprimes."
    fi
}

#==============================================================================
#  3. PRIMITIVES DE DESSIN
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
#  4. TUX (ASCII, 4 images d'animation)
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
#  5. INFORMATIONS MACHINE
#==============================================================================

MI_HOST=""; MI_IP=""; MI_OS=""
MI_FW=""; MI_FW_ST="warn"
MI_P80=""; MI_P80_ST="warn"
MI_P443=""; MI_P443_ST="warn"
MI_CPU=0; MI_CPU_TXT=""; MI_CPU_ST="ok"
MI_RAM=0; MI_RAM_TXT=""; MI_RAM_ST="ok"
MI_DISK=0; MI_DISK_TXT=""; MI_DISK_ST="ok"

# Seuils materiels (Mo pour la memoire et le disque).
# En dessous du seuil "MIN" l'installation est fortement deconseillee,
# entre "MIN" et "RECO" elle fonctionne mais sans confort.
HW_CPU_RECO=2
HW_RAM_MIN=1024
HW_RAM_RECO=2048
HW_DISK_MIN=2048
HW_DISK_RECO=5120

declare -a HW_ISSUES HW_SHORT

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
    # "Debian GNU/Linux 12 (bookworm)" -> "Debian 12", pour tenir dans le panneau
    os=${os// GNU\/Linux/}
    os=${os%% (*}
    printf '%s' "$os"
}

detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -qiE '^(Status|Statut)[[:space:]]*:[[:space:]]*(active|actif)'; then
            MI_FW="$L_V_ACTIVE (ufw)"; MI_FW_ST="ok"; return
        fi
        MI_FW="$L_V_INACTIVE (ufw)"; MI_FW_ST="warn"; return
    fi
    if command -v nft >/dev/null 2>&1 && [[ -n $(nft list ruleset 2>/dev/null) ]]; then
        MI_FW="$L_V_ACTIVE (nftables)"; MI_FW_ST="ok"; return
    fi
    if command -v iptables >/dev/null 2>&1 && (( $(iptables -S 2>/dev/null | wc -l) > 3 )); then
        MI_FW="$L_V_ACTIVE (iptables)"; MI_FW_ST="ok"; return
    fi
    MI_FW="$L_V_NONE"; MI_FW_ST="warn"
}

# port_state <port> -> PORT_TXT / PORT_ST
port_state() {
    local port=$1 line proc=""
    if command -v ss >/dev/null 2>&1; then
        line=$(ss -lntpH 2>/dev/null | awk -v p=":$port" '{ if (index($4, p) && substr($4, length($4)-length(p)+1) == p) print }')
    elif command -v netstat >/dev/null 2>&1; then
        line=$(netstat -lntp 2>/dev/null | awk -v p=":$port" '{ if (substr($4, length($4)-length(p)+1) == p) print }')
    else
        PORT_TXT="$L_V_UNKNOWN"; PORT_ST="warn"; return
    fi
    if [[ -z $line ]]; then
        PORT_TXT="$L_V_FREE"; PORT_ST="ok"
    else
        proc=$(printf '%s' "$line" | grep -oE '"[^"]+"' | head -n1 | tr -d '"')
        [[ -z $proc ]] && proc=$(printf '%s' "$line" | awk '{print $NF}' | cut -d/ -f2)
        if [[ -n $proc ]]; then
            PORT_TXT="$L_V_BUSY ($proc)"
        else
            PORT_TXT="$L_V_BUSY"
        fi
        PORT_ST="err"
    fi
}

# human_mb <taille en Mo> -> "1,9 Go" ou "512 Mo"
human_mb() {
    local m=$1 g d
    if (( m >= 1024 )); then
        g=$(( m / 1024 )); d=$(( (m % 1024) * 10 / 1024 ))
        if (( d == 0 )); then
            printf '%d %s' "$g" "$L_U_GB"
        else
            printf '%d%s%d %s' "$g" "$L_DECIMAL" "$d" "$L_U_GB"
        fi
    else
        printf '%d %s' "$m" "$L_U_MB"
    fi
}

get_cpu_count() {
    local n
    n=$(nproc 2>/dev/null)
    [[ $n =~ ^[0-9]+$ ]] || n=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
    [[ $n =~ ^[0-9]+$ ]] || n=0
    printf '%s' "$n"
}

get_ram_mb() {
    local m
    m=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
    [[ $m =~ ^[0-9]+$ ]] || m=0
    printf '%s' "$m"
}

# Espace libre sur le systeme de fichiers qui accueillera GLPI et la base
get_disk_mb() {
    local m
    m=$(df -Pm /var 2>/dev/null | awk 'NR==2 {print $4}')
    [[ $m =~ ^[0-9]+$ ]] || m=0
    printf '%s' "$m"
}

# hw_issue <libelle> <valeur> <recommandation> -> ligne alignee du rapport
hw_issue() {
    printf '%-13s: %s (%s)' "$1" "$2" "$3"
}

check_hardware() {
    HW_ISSUES=()
    HW_SHORT=()

    MI_CPU=$(get_cpu_count)
    if (( MI_CPU <= 0 )); then
        MI_CPU_TXT="$L_V_UNKNOWN"; MI_CPU_ST="warn"
    else
        if (( MI_CPU > 1 )); then MI_CPU_TXT="$MI_CPU $L_V_CORES"; else MI_CPU_TXT="$MI_CPU $L_V_CORE"; fi
        if (( MI_CPU < HW_CPU_RECO )); then
            MI_CPU_ST="warn"
            HW_ISSUES+=("$(hw_issue "$L_HW_L_CPU" "$MI_CPU_TXT" "$(printf "$L_HW_RECO_CPU" "$HW_CPU_RECO")")")
            HW_SHORT+=("$L_HW_SHORT_CPU")
        else
            MI_CPU_ST="ok"
        fi
    fi

    MI_RAM=$(get_ram_mb)
    MI_RAM_TXT=$(human_mb "$MI_RAM")
    if (( MI_RAM <= 0 )); then
        MI_RAM_TXT="$L_V_UNKNOWN_F"; MI_RAM_ST="warn"
    elif (( MI_RAM < HW_RAM_MIN )); then
        MI_RAM_ST="err"
        HW_ISSUES+=("$(hw_issue "$L_HW_L_RAM" "$MI_RAM_TXT" "$L_HW_INSUF_F, $(printf "$L_HW_RECO" "$(human_mb $HW_RAM_RECO)")")")
        HW_SHORT+=("$L_HW_SHORT_RAM")
    elif (( MI_RAM < HW_RAM_RECO )); then
        MI_RAM_ST="warn"
        HW_ISSUES+=("$(hw_issue "$L_HW_L_RAM" "$MI_RAM_TXT" "$(printf "$L_HW_RECO" "$(human_mb $HW_RAM_RECO)")")")
        HW_SHORT+=("$L_HW_SHORT_RAM")
    else
        MI_RAM_ST="ok"
    fi

    MI_DISK=$(get_disk_mb)
    local libre="$L_V_SPACE_FREE_P"
    (( MI_DISK < 2048 )) && libre="$L_V_SPACE_FREE"
    MI_DISK_TXT="$(human_mb "$MI_DISK") $libre"
    if (( MI_DISK <= 0 )); then
        MI_DISK_TXT="$L_V_UNKNOWN"; MI_DISK_ST="warn"
    elif (( MI_DISK < HW_DISK_MIN )); then
        MI_DISK_ST="err"
        HW_ISSUES+=("$(hw_issue "$L_HW_L_DISK" "$MI_DISK_TXT" "$L_HW_INSUF, $(printf "$L_HW_RECO" "$(human_mb $HW_DISK_RECO)")")")
        HW_SHORT+=("$L_HW_SHORT_DISK")
    elif (( MI_DISK < HW_DISK_RECO )); then
        MI_DISK_ST="warn"
        HW_ISSUES+=("$(hw_issue "$L_HW_L_DISK" "$MI_DISK_TXT" "$(printf "$L_HW_RECO" "$(human_mb $HW_DISK_RECO)")")")
        HW_SHORT+=("$L_HW_SHORT_DISK")
    else
        MI_DISK_ST="ok"
    fi
}

hw_is_critical() {
    [[ $MI_RAM_ST == err || $MI_DISK_ST == err ]]
}

hw_warning_text() {
    local head=$L_HW_HEAD conseq=$L_HW_CONSEQ
    if hw_is_critical; then
        head=$L_HW_HEAD_CRIT
        conseq=$L_HW_CONSEQ_CRIT
    fi
    printf '%s\n\n' "$head"
    printf '  %s\n' "${HW_ISSUES[@]}"
    printf '\n%s\n' "$conseq"
    printf '\n%s\n' "$L_HW_CONTINUE"
}

collect_machine_info() {
    MI_HOST=$(hostname 2>/dev/null || printf '%s' "$L_V_UNKNOWN")
    MI_IP=$(get_ip)
    MI_OS=$(get_os)
    check_hardware
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
#  6. MODELE DU FORMULAIRE
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
    add_section "$L_SEC_DB"
    add_field db_name  "$L_F_DBNAME" text "glpidb"   "$L_H_DBNAME"
    add_field db_user  "$L_F_DBUSER" text "glpiuser" "$L_H_DBUSER"
    add_field db_auto  "$L_F_DBAUTO" bool "oui"      "$L_H_DBAUTO"
    add_field db_pass  "$L_F_DBPASS" pass ""         "$L_H_DBPASS" "db_auto=non"

    add_section "$L_SEC_SECURITY"
    add_field root_pass "$L_F_ROOTPASS" pass ""        "$(printf "$L_H_ROOTPASS" "$MYSQL_CRED")"
    add_field db_remote "$L_F_REMOTE"   bool "non" "$L_H_REMOTE"
    add_field firewall  "$L_F_FIREWALL" bool "oui" "$L_H_FIREWALL"

    add_section "$L_SEC_WEB"
    add_field domain   "$L_F_DOMAIN"  text ""         "$L_H_DOMAIN"
    add_field ssl      "$L_F_SSL"     bool "oui"      "$L_H_SSL"
    add_field ssl_days "$L_F_SSLDAYS" num  "365"      "$L_H_SSLDAYS" "ssl=oui"

    add_section "$L_SEC_OPTIONS"
    add_field uninstaller "$L_F_UNINSTALL" bool "oui" "$L_H_UNINSTALL"
    add_field tests       "$L_F_TESTS"     bool "oui" "$L_H_TESTS"
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
            if [[ $v == oui ]]; then DISPV="< $L_YESV >"; DISPC=$C_OK
            else DISPV="< $L_NOV >"; DISPC=$C_MUTED; fi
            ;;
        pass)
            if [[ -z $v ]]; then DISPV="($L_UNSET)"; DISPC=$C_WARN
            else
                local n=${#v}; (( n > 16 )) && n=16
                rep_char '*' "$n"; DISPV=$REPC; DISPC=$C_VALUE
            fi
            ;;
        *)
            if [[ -z $v ]]; then DISPV="($L_EMPTY)"; DISPC=$C_WARN
            else DISPV=$v; DISPC=$C_VALUE; fi
            ;;
    esac
}

#==============================================================================
#  7. RENDU DE L'ECRAN PRINCIPAL
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
    local title="$L_APP_TITLE"
    draw_box "$HEAD_Y" 1 "$HEAD_H" "$COLS" "" "$C_FRAME"
    local x=$(( (COLS - ${#title}) / 2 ))
    (( x < 2 )) && x=2
    put $(( HEAD_Y + 1 )) "$x" "${C_BOLD}${C_TITLE}${title}${C_RESET}"
    put $(( HEAD_Y + 1 )) $(( COLS - 10 )) "${C_MUTED}v${SCRIPT_VERSION}${C_RESET}"
}

render_form() {
    local col=$C_FRAME
    sel_is_button || col=$C_FRAME_ON
    draw_box "$BODY_Y" "$FORM_X" "$BODY_H" "$FORM_W" "$L_PANEL_CONFIG" "$col"

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
    draw_box "$BODY_Y" "$RIGHT_X" "$MACH_H" "$RIGHT_W" "$L_PANEL_MACHINE" "$C_FRAME"
    local inner=$(( RIGHT_W - 4 ))
    local labw=12
    local y=$(( BODY_Y + 1 ))
    local -a rows
    if (( MACH_H >= 11 )); then
        rows=(
            "$L_M_HOST|$MI_HOST|"
            "$L_M_IP|$MI_IP|"
            "$L_M_OS|$MI_OS|"
            "$L_M_CPU|$MI_CPU_TXT|$MI_CPU_ST"
            "$L_M_RAM|$MI_RAM_TXT|$MI_RAM_ST"
            "$L_M_DISK|$MI_DISK_TXT|$MI_DISK_ST"
            "$L_M_FW|$MI_FW|$MI_FW_ST"
            "$L_M_P80|$MI_P80|$MI_P80_ST"
            "$L_M_P443|$MI_P443|$MI_P443_ST"
        )
    else
        # ecran court : on regroupe pour ne rien perdre d'essentiel
        local hw_st="ok"
        [[ $MI_CPU_ST == warn || $MI_RAM_ST == warn ]] && hw_st="warn"
        [[ $MI_RAM_ST == err ]] && hw_st="err"
        local ports_st="ok"
        [[ $MI_P80_ST == err || $MI_P443_ST == err ]] && ports_st="err"
        rows=(
            "$L_M_HOST|$MI_HOST|"
            "$L_M_IP|$MI_IP|"
            "$L_M_CPURAM|$MI_CPU / $MI_RAM_TXT|$hw_st"
            "$L_M_DISK|$MI_DISK_TXT|$MI_DISK_ST"
            "$L_M_FW|$MI_FW|$MI_FW_ST"
            "$L_M_PORTS|$MI_P80 / $MI_P443|$ports_st"
        )
    fi
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
}

render_help() {
    local y=$(( BODY_Y + MACH_H ))
    draw_box "$y" "$RIGHT_X" "$HELP_H" "$RIGHT_W" "$L_PANEL_KEYS" "$C_FRAME"
    local inner=$(( RIGHT_W - 4 ))
    local keys=("${L_KEYS[@]}")
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
            "$L_NOTE_TARGET"
            "  $GLPI_DIR"
            "$L_NOTE_LOG"
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
    local col=$C_FRAME lab="$L_BTN_INSTALL"
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
            txt="$L_ST_BUTTON"
        else
            local i=${VR_IDX[$SEL]}
            if [[ ${VR_TYPE[$SEL]} == fld ]]; then
                txt=${FLD_HINT[i]}
            elif [[ ${VR_TYPE[$SEL]} == sec ]]; then
                txt="$L_ST_SECTION"
            fi
        fi
    fi
    pad_str " $txt" "$COLS"
    put "$ROWS" 1 "${c}${PAD}${C_RESET}"
}

render_main() {
    BUF=$'\e[2J'
    if term_too_small; then
        put 1 1 "${C_ERR}$(printf "$L_TOO_SMALL" "$COLS" "$ROWS")${C_RESET}"
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
#  8. SAISIE CLAVIER
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
#  9. FENETRES MODALES
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
    pad_str "$L_ANY_KEY" $(( w - 4 ))
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
    (( h > ROWS - 2 )) && h=$(( ROWS - 2 ))
    local maxl=$(( h - 5 ))
    modal_box "$h" "$w" "$title"
    while :; do
        BUF=""
        local i
        for (( i = 0; i < ${#lines[@]} && i < maxl; i++ )); do
            pad_str "${lines[i]}" $(( w - 4 ))
            put $(( MY + 1 + i )) $(( MX + 2 )) "${C_VALUE}${PAD}${C_RESET}"
        done
        local yes="$L_YES" no="$L_NO"
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
    pad_str "$L_EDIT_HELP" $(( w - 4 ))
    put $(( MY + 6 )) $(( MX + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    edit_line $(( MY + 4 )) $(( MX + 3 )) $(( w - 6 )) "$cur" "$mask"
}

# --- Choix de la langue au demarrage ---------------------------------------
# Renvoie 0 si une langue a ete choisie, 1 si l'utilisateur abandonne.
select_language() {
    local sel=0 i
    local -a codes=("fr" "en")
    local -a names=("Francais" "English")

    case "${GLPI_LANG:-}" in
        fr|FR|fr_FR) UILANG="fr"; return 0 ;;
        en|EN|en_US) UILANG="en"; return 0 ;;
    esac

    while :; do
        (( RESIZED )) && { compute_layout; RESIZED=0; }
        local w=46 h=10
        (( w > COLS - 4 )) && w=$(( COLS - 4 ))
        local y=$(( (ROWS - h) / 2 )) x=$(( (COLS - w) / 2 ))
        (( y < 1 )) && y=1
        (( x < 1 )) && x=1

        BUF=$'\e[2J'
        draw_box "$y" "$x" "$h" "$w" "GLPI AUTO" "$C_FRAME_ON"
        pad_str "Choisissez votre langue" $(( w - 4 ))
        put $(( y + 1 )) $(( x + 2 )) "${C_LABEL}${PAD}${C_RESET}"
        pad_str "Choose your language" $(( w - 4 ))
        put $(( y + 2 )) $(( x + 2 )) "${C_MUTED}${PAD}${C_RESET}"
        for (( i = 0; i < ${#names[@]}; i++ )); do
            pad_str "${names[i]}" $(( w - 8 ))
            if (( sel == i )); then
                put $(( y + 4 + i )) $(( x + 2 )) "${C_SEL}${C_BOLD}${C_VALUE}  > ${PAD} ${C_RESET}"
            else
                put $(( y + 4 + i )) $(( x + 2 )) "${C_VALUE}    ${PAD} ${C_RESET}"
            fi
        done
        pad_str "Fleches + Entree / Arrows + Enter" $(( w - 4 ))
        put $(( y + h - 2 )) $(( x + 2 )) "${C_MUTED}${PAD}${C_RESET}"
        printf '%s' "$BUF"

        read_key
        case $KEY in
            UP|"CHAR:k")   (( sel > 0 )) && sel=$(( sel - 1 )) ;;
            DOWN|"CHAR:j"|TAB) (( sel < ${#names[@]} - 1 )) && sel=$(( sel + 1 )) ;;
            "CHAR:f"|"CHAR:F") sel=0 ;;
            "CHAR:e"|"CHAR:E") sel=1 ;;
            ENTER|SPACE) UILANG=${codes[sel]}; return 0 ;;
            ESC|"CHAR:q"|"CHAR:Q") return 1 ;;
        esac
    done
}

#==============================================================================
#  10. INTERACTION AVEC LE FORMULAIRE
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
            [[ $v =~ ^[a-zA-Z0-9_]+$ ]] || VERR="$L_ERR_IDENT"
            ;;
        pass)
            if (( ${#v} < 8 )); then VERR="$L_ERR_PASS_SHORT"
            elif [[ $v =~ [\'\"\\\`\ ] ]]; then VERR="$L_ERR_PASS_CHARS"
            fi
            ;;
        host)
            [[ $v =~ ^[a-zA-Z0-9._-]+$ ]] || VERR="$L_ERR_HOST"
            ;;
        days)
            if [[ ! $v =~ ^[0-9]+$ ]]; then VERR="$L_ERR_DAYS_NUM"
            elif (( v < 1 || v > 3650 )); then VERR="$L_ERR_DAYS_RANGE"
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
            modal_message "$L_INVALID_T" "$VERR" "$C_ERR"
            continue
        fi
        if (( mask )); then
            modal_edit "${FLD_LABEL[i]}" "$L_PASS_CONFIRM" "" 1 "$L_PASS_RETYPE" || return
            if [[ $EDITED != "$v" ]]; then
                modal_message "$L_PASS_MISMATCH_T" "$L_PASS_MISMATCH" "$C_ERR"
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
            FERR="$L_F_DBPASS : $VERR"; FKEY="db_pass"; return 1
        fi
    fi
    if ! validate_value pass "${VAL[root_pass]}"; then
        FERR="$L_F_ROOTPASS : $VERR"; FKEY="root_pass"; return 1
    fi
    if [[ ${VAL[ssl]} == oui ]] && ! validate_value days "${VAL[ssl_days]}"; then
        FERR="$L_F_SSLDAYS : $VERR"; FKEY="ssl_days"; return 1
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
#  11. ECRANS D'ANIMATION (TUX + BARRE DE PROGRESSION)
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
    local title="$L_ANIM_DL_TITLE"
    [[ $ANIM_MODE == install ]] && title="$L_ANIM_INST_TITLE"
    BUF=$'\e[2J'
    draw_box "$ANIM_Y" "$ANIM_X" "$ANIM_H" "$ANIM_W" "$title" "$C_FRAME_ON"
    pad_str " $(printf "$L_ANIM_LOG" "$LOGFILE")" "$COLS"
    put "$ROWS" 1 "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    RESIZED=0
    anim_tick
}

human_size() {
    local b=$1
    if (( b >= 1048576 )); then
        printf '%d%s%d %s' $(( b / 1048576 )) "$L_DECIMAL" $(( (b % 1048576) * 10 / 1048576 )) "$L_U_MB"
    elif (( b >= 1024 )); then
        printf '%d %s' $(( b / 1024 )) "$L_U_KB"
    else
        printf '%d %s' "$b" "$L_U_B"
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
        (( cur > 0 )) && { printf "$L_DL_RECEIVED" "$(human_size "$cur")"; return; }
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
        ptitle="${L_ANIM_INST_PHASE}${dots}"
    else
        ptitle="$L_ANIM_DL_PHASE"
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
#  12. SONDES DE PROGRESSION
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
#  13. MOTEUR D'EXECUTION DES ETAPES
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
    modal_message "$L_FATAL_T" \
"$msg

$L_FATAL_LOGTAIL
${tail_log:-$L_FATAL_NONE}

$(printf "$L_FATAL_LOG" "$LOGFILE")" "$C_ERR"
    tui_stop
    printf "$L_FATAL_CLI\n" "$msg" >&2
    printf "$L_FATAL_CLI2\n" "$LOGFILE" >&2
    exit 1
}

#==============================================================================
#  14. TACHES D'INSTALLATION
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
        sed -i "s/^;*[[:space:]]*intl.default_locale[[:space:]]*=.*/intl.default_locale = $PHP_LOCALE/" "$ini"
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
# $L_UN_HEAD
export PATH=\$PATH:/usr/sbin:/sbin

echo "$L_UN_FILES"
rm -rf "$GLPI_DIR" "$GLPI_ARCHIVE" "$GLPI_DATA"

echo "$L_UN_APACHE"
rm -f /etc/apache2/sites-available/glpi.conf /etc/apache2/sites-available/glpi-ssl.conf
rm -rf "$SSL_DIR"
a2dissite glpi.conf 2>/dev/null
a2dissite glpi-ssl.conf 2>/dev/null
a2ensite 000-default.conf 2>/dev/null
systemctl reload apache2 2>/dev/null

echo "$L_UN_DB"
if [ -f "$MYSQL_CRED" ]; then
  mysql --defaults-file="$MYSQL_CRED" -e "DROP DATABASE IF EXISTS \\\`$DB_NAME\\\`;"
  mysql --defaults-file="$MYSQL_CRED" -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
  mysql --defaults-file="$MYSQL_CRED" -e "DROP USER IF EXISTS '$DB_USER'@'%';"
else
  echo "$L_UN_NOCRED"
  echo "$(printf "$L_UN_MANUAL" "$DB_NAME" "$DB_USER")"
fi

echo "$L_UN_DONE"
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
#  15. DEROULEMENT DE L'INSTALLATION
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

    step_run "$L_S_APT_UPDATE" 0 10 probe_apt_update \
        do_apt_update \
        || fatal "$L_E_APT_UPDATE"

    step_run "$L_S_APT_WEB" 10 40 probe_apt \
        do_apt_install apache2 mariadb-server \
        || fatal "$L_E_APT_WEB"

    step_run "$L_S_APT_PHP" 40 70 probe_apt \
        do_apt_install php php-mysql php-xml php-mbstring php-curl php-gd php-intl \
                       php-ldap php-imap php-zip php-bz2 php-cli php-apcu php-bcmath \
                       php-opcache php-exif libapache2-mod-php \
        || fatal "$L_E_APT_PHP"

    step_run "$L_S_APT_TOOLS" 70 78 probe_apt \
        do_apt_install unzip wget tar curl openssl ca-certificates \
        || fatal "$L_E_APT_TOOLS"

    step_run "$L_S_FETCH" 78 82 - \
        do_fetch_glpi_url \
        || fatal "$L_E_FETCH"

    GLPI_URL=$(cat /tmp/glpi-url.txt 2>/dev/null)
    [[ -z $GLPI_URL ]] && GLPI_URL="$GLPI_FALLBACK_URL"
    log_line "Archive: $GLPI_URL"

    STEP_LABEL="$L_S_PREPARE_DL"
    anim_tick
    DL_FILE="$GLPI_ARCHIVE"
    DL_TOTAL=$(wget --spider -S "$GLPI_URL" 2>&1 | awk '/[Cc]ontent-[Ll]ength:/ {print $2}' | tail -n1 | tr -d '\r')
    [[ $DL_TOTAL =~ ^[0-9]+$ ]] || DL_TOTAL=0

    step_run "$L_S_DOWNLOAD" 82 100 probe_wget \
        do_download_glpi \
        || fatal "$L_E_DOWNLOAD"

    DL_FILE=""
    sleep 0.4

    #------------------------------------------------------ phase 2 : INSTALL
    anim_begin install

    step_run "$L_S_EXTRACT" 0 14 - \
        do_extract_glpi \
        || fatal "$L_E_EXTRACT"

    step_run "$L_S_MOVE" 14 20 - \
        do_move_glpi \
        || fatal "$L_E_MOVE"

    step_run "$L_S_CREATE_DB" 20 30 - \
        do_create_db \
        || fatal "$L_E_CREATE_DB"

    step_run "$L_S_SECURE_DB" 30 40 - \
        do_secure_mariadb \
        || fatal "$L_E_SECURE_DB"

    step_run "$L_S_BIND_DB" 40 48 - \
        do_bind_mariadb \
        || fatal "$L_E_BIND_DB"

    step_run "$L_S_PERMS" 48 58 - \
        do_permissions \
        || fatal "$L_E_PERMS"

    step_run "$L_S_APACHE" 58 72 - \
        do_apache_vhost \
        || fatal "$L_E_APACHE"

    step_run "$L_S_PHP" 72 78 - \
        do_php_config \
        || fatal "$L_E_PHP"

    step_run "$L_S_HTACCESS" 78 84 - \
        do_htaccess \
        || fatal "$L_E_HTACCESS"

    if [[ ${VAL[firewall]} == oui ]]; then
        step_run "$L_S_FIREWALL" 84 92 - \
            do_firewall \
            || fatal "$L_E_FIREWALL"
    else
        PCT=92; STEP_LABEL="$L_S_FIREWALL_SKIP"; anim_tick
    fi

    if [[ ${VAL[uninstaller]} == oui ]]; then
        step_run "$L_S_UNINSTALL" 92 96 - \
            do_uninstaller \
            || fatal "$L_E_UNINSTALL"
    fi

    step_run "$L_S_CLEANUP" 96 100 - do_cleanup_logs

    STEP_LABEL="$L_S_DONE"
    PCT=100
    anim_tick
    sleep 0.6
}

#==============================================================================
#  16. ECRAN FINAL
#==============================================================================

run_tests() {
    TEST_APACHE="$L_TEST_APACHE_DOWN"
    TEST_MDB="$L_TEST_MDB_DOWN"
    TEST_DIR="$L_TEST_DIR_KO"
    systemctl is-active --quiet apache2 && TEST_APACHE="$L_TEST_APACHE_UP"
    systemctl is-active --quiet mariadb && TEST_MDB="$L_TEST_MDB_UP"
    [[ -d $GLPI_DIR ]] && TEST_DIR="$L_TEST_DIR_OK"
}

final_screen() {
    local proto="http" port=""
    [[ $SSL_ON == oui ]] && proto="https"
    local url="$proto://$DOMAIN/"

    local tests=""
    if [[ ${VAL[tests]} == oui ]]; then
        run_tests
        tests="

$L_TEST_HEAD
  $TEST_APACHE
  $TEST_MDB
  $TEST_DIR"
    fi

    local uninst=""
    [[ ${VAL[uninstaller]} == oui ]] && uninst="

$L_FINAL_UNINSTALL"

    RECAP="$L_FINAL_DONE

$(printf '%-15s : %s' "$L_FINAL_URL" "$url")
$(printf '%-15s : %s' "$L_FINAL_IP" "$MI_IP")

$(printf '%-15s : %s' "$L_FINAL_DB" "$DB_NAME")
$(printf '%-15s : %s' "$L_FINAL_USER" "$DB_USER")
$(printf '%-15s : %s' "$L_FINAL_PASS" "$DB_PASS")
$(printf '%-15s : ' "$L_FINAL_ROOT")$(printf "$L_FINAL_ROOT_V" "$MYSQL_CRED")

$L_FINAL_DEFAULT
$(printf "$L_FINAL_WARN" "$GLPI_DIR/install")$tests$uninst

$(printf '%-15s : %s' "$L_FINAL_LOG" "$LOGFILE")"

    compute_layout
    BUF=$'\e[2J'
    local w=$(( COLS - 8 ))
    (( w > 76 )) && w=76
    local -a lines
    local l
    while IFS= read -r l; do lines+=("$l"); done <<<"$RECAP"
    # ecran trop court : on supprime d'abord les lignes vides plutot que de
    # tronquer la fin du recapitulatif
    if (( ${#lines[@]} + 4 > ROWS - 2 )); then
        local -a compact=()
        for l in "${lines[@]}"; do [[ -n $l ]] && compact+=("$l"); done
        lines=("${compact[@]}")
    fi
    local h=$(( ${#lines[@]} + 4 ))
    (( h > ROWS - 2 )) && h=$(( ROWS - 2 ))
    local y=$(( (ROWS - h) / 2 )) x=$(( (COLS - w) / 2 ))
    (( y < 1 )) && y=1
    (( x < 1 )) && x=1
    draw_box "$y" "$x" "$h" "$w" "$L_FINAL_T" "$C_FRAME_ON"
    local i c
    for (( i = 0; i < ${#lines[@]} && i < h - 4; i++ )); do
        c=$C_VALUE
        [[ ${lines[i]} == ATTENTION* || ${lines[i]} == WARNING* ]] && c=$C_WARN
        [[ ${lines[i]} == "$L_FINAL_DONE" ]] && c=$C_OK
        pad_str "${lines[i]}" $(( w - 4 ))
        put $(( y + 1 + i )) $(( x + 2 )) "${c}${PAD}${C_RESET}"
    done
    pad_str "$L_ANY_KEY_QUIT" $(( w - 4 ))
    put $(( y + h - 2 )) $(( x + 2 )) "${C_MUTED}${PAD}${C_RESET}"
    printf '%s' "$BUF"
    wait_key
}

#==============================================================================
#  17. VERIFICATIONS PREALABLES
#==============================================================================

precheck() {
    if [[ $EUID -ne 0 ]]; then
        printf '%s\n' "Ce script doit etre execute avec sudo ou en tant que root." >&2
        printf '%s\n' "This script must be run with sudo or as root." >&2
        exit 1
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        printf '%s\n' "Ce script necessite un terminal interactif." >&2
        printf '%s\n' "This script requires an interactive terminal." >&2
        exit 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        printf '%s\n' "Systeme non supporte : apt-get est introuvable (Debian 12 attendu)." >&2
        printf '%s\n' "Unsupported system: apt-get not found (Debian 12 expected)." >&2
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
#  18. BOUCLE PRINCIPALE
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
$(printf "$L_CONFIRM_EXISTS" "$GLPI_DIR")
"
                        if (( ${#HW_SHORT[@]} > 0 )); then
                            local causes="${HW_SHORT[*]}"
                            extra+="
$L_CONFIRM_HW
(${causes// /, })
"
                        fi
                        if modal_confirm "$L_CONFIRM_T" \
"$L_CONFIRM_BODY
$extra
$L_CONFIRM_ASK"; then
                            return 0
                        fi
                    else
                        modal_message "$L_FORM_INCOMPLETE_T" "$FERR" "$C_ERR"
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
                    STATUS_MSG="$L_ST_THEME_LIGHT"
                else
                    STATUS_MSG="$L_ST_THEME_DARK"
                fi
                STATUS_KIND="ok"
                ;;
            "CHAR:r"|"CHAR:R")
                STATUS_MSG="$L_ST_REFRESHING"
                STATUS_KIND="info"
                render_main
                collect_machine_info
                STATUS_MSG="$L_ST_REFRESHED"
                STATUS_KIND="ok"
                ;;
            "CHAR:q"|"CHAR:Q"|ESC)
                if modal_confirm "$L_QUIT_T" "$L_QUIT_ASK"; then
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

    trap cleanup EXIT
    trap 'cleanup; exit 130' INT TERM
    trap on_resize WINCH

    compute_layout
    tui_start

    # la couleur de fond est demandee une fois l'ecran alternatif actif :
    # une eventuelle reponse non consommee reste invisible pour l'utilisateur
    detect_theme
    setup_colors

    if ! select_language; then
        cleanup
        printf '%s\n' "Installation annulee. / Installation cancelled."
        exit 0
    fi
    load_strings
    build_form
    if [[ $UILANG == en ]]; then PHP_LOCALE="en_US"; else PHP_LOCALE="fr_FR"; fi

    collect_machine_info
    VAL[domain]="$MI_IP"

    if term_too_small; then
        render_main
        wait_key
        cleanup
        printf '%s\n' "$L_TOO_SMALL_CLI" >&2
        exit 1
    fi

    if (( ${#HW_ISSUES[@]} > 0 )); then
        local hwcol=$C_WARN
        hw_is_critical && hwcol=$C_ERR
        modal_message "$L_HW_T" "$(hw_warning_text)" "$hwcol"
    fi

    if ! check_internet; then
        modal_message "$L_NET_T" "$L_NET_BODY" "$C_ERR"
    fi

    if ! main_loop; then
        cleanup
        printf '%s\n' "$L_CANCELLED"
        exit 0
    fi

    run_install
    final_screen

    cleanup
    trap - EXIT
    printf '%s\n' "$RECAP"
}

main "$@"
