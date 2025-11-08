#!/bin/bash
# Interactive GLPI installation script for Debian 12
# Author: Alexandre

export PATH=$PATH:/usr/sbin:/sbin
LOGFILE="/var/log/glpi-install.log"
exec > >(tee -i "$LOGFILE") 2>&1

# --- Système de traduction ---
declare -A TRANSLATIONS

init_translations() {
    # === FRANÇAIS ===
    TRANSLATIONS[fr_ERROR_TITLE]="Erreur"
    TRANSLATIONS[fr_SCRIPT_STOP]="Le script va s'arrêter."
    TRANSLATIONS[fr_ROOT_CHECK]="Ce script doit être exécuté avec sudo ou en tant que root."
    TRANSLATIONS[fr_INSTALL_CANCEL]="Installation annulée par l'utilisateur."
    TRANSLATIONS[fr_NO_INTERNET]="Pas de connexion Internet"
    
    # Menus et titres
    TRANSLATIONS[fr_LANG_TITLE]="Choix de la langue"
    TRANSLATIONS[fr_LANG_PROMPT]="Choisissez votre langue :"
    TRANSLATIONS[fr_INSTALL_TITLE]="Installation GLPI"
    TRANSLATIONS[fr_CONTINUE_PROMPT]="Ce script effectue une installation automatique de GLPI.\nSouhaitez-vous continuer ?"
    
    # Base de données
    TRANSLATIONS[fr_DB_TITLE]="Base de données"
    TRANSLATIONS[fr_DB_NAME_PROMPT]="Entrez le nom de la base MySQL :"
    TRANSLATIONS[fr_DB_USER_TITLE]="Utilisateur MySQL"
    TRANSLATIONS[fr_DB_USER_PROMPT]="Entrez le nom d'utilisateur MySQL :"
    TRANSLATIONS[fr_DB_PASS_TITLE]="Mot de passe MySQL"
    TRANSLATIONS[fr_DB_PASS_GEN]="Souhaitez-vous générer un mot de passe fort pour l'utilisateur"
    TRANSLATIONS[fr_DB_PASS_GENERATED]="Mot de passe MySQL généré automatiquement :\n\n"
    TRANSLATIONS[fr_DB_PASS_ENTER]="Entrez le mot de passe pour"
    TRANSLATIONS[fr_DB_PASS_CONFIRM]="Confirmez le mot de passe"
    TRANSLATIONS[fr_DB_PASS_REENTER]="Ressaisissez le mot de passe pour vérification :"
    TRANSLATIONS[fr_DB_PASS_MISMATCH]="Mot de passe différent"
    TRANSLATIONS[fr_DB_PASS_NOMATCH]="Les deux mots de passe ne correspondent pas.\n\nVeuillez réessayer."
    
    # MariaDB Sécurité
    TRANSLATIONS[fr_MDB_SECURITY_TITLE]="Sécurité MariaDB"
    TRANSLATIONS[fr_MDB_WARNING]="ATTENTION SÉCURITÉ !\n\nMariaDB va être configuré pour écouter sur toutes les interfaces (0.0.0.0).\n\nCela signifie que votre base de données sera accessible depuis le réseau.\n\nAssurez-vous que :\n• Votre pare-feu est correctement configuré\n• Le port 3306 n'est PAS exposé sur Internet\n• Vous utilisez un mot de passe fort\n\nVoulez-vous vraiment activer l'accès distant ?"
    TRANSLATIONS[fr_MDB_LOCAL_ONLY]="MariaDB restera accessible uniquement en local (127.0.0.1).\n\nPour un accès distant ultérieur, modifiez manuellement :\n/etc/mysql/mariadb.conf.d/50-server.cnf"
    
    # SSL
    TRANSLATIONS[fr_SSL_TITLE]="Certificat HTTPS"
    TRANSLATIONS[fr_DOMAIN_PROMPT]="Entrez le domaine ou l'IP du serveur :"
    TRANSLATIONS[fr_SSL_CREATE]="Voulez-vous créer un certificat HTTPS auto-signé pour"
    TRANSLATIONS[fr_SSL_DAYS_TITLE]="Durée du certificat"
    TRANSLATIONS[fr_SSL_DAYS_PROMPT]="Durée de validité (jours) :"
    
    # Messages de progression
    TRANSLATIONS[fr_UPDATE_DEPS]="Mise à jour des paquets et installation des dépendances..."
    TRANSLATIONS[fr_SETUP_DB]="Configuration de la base de données"
    TRANSLATIONS[fr_DOWNLOAD_GLPI]="Téléchargement et extraction de GLPI..."
    TRANSLATIONS[fr_STEP_UPDATE]="Mise à jour des listes de paquets..."
    TRANSLATIONS[fr_STEP_APACHE]="Installation Apache & MariaDB..."
    TRANSLATIONS[fr_STEP_PHP]="Installation extensions PHP 8.2..."
    TRANSLATIONS[fr_STEP_UTILS]="Installation utilitaires..."
    TRANSLATIONS[fr_STEP_COMPLETE]="Dépendances installées !"
    TRANSLATIONS[fr_STEP_CREATE_DB]="Création de la base de données..."
    TRANSLATIONS[fr_STEP_DROP_USERS]="Suppression anciens utilisateurs..."
    TRANSLATIONS[fr_STEP_CREATE_USERS]="Création utilisateurs MySQL..."
    TRANSLATIONS[fr_STEP_GRANT]="Attribution des privilèges..."
    TRANSLATIONS[fr_STEP_DB_READY]="Base de données prête !"
    TRANSLATIONS[fr_STEP_FETCH_VERSION]="Recherche dernière version GLPI..."
    TRANSLATIONS[fr_STEP_DOWNLOADING]="Téléchargement archive GLPI..."
    TRANSLATIONS[fr_STEP_EXTRACTING]="Extraction des fichiers..."
    TRANSLATIONS[fr_STEP_MOVING]="Déplacement des fichiers..."
    TRANSLATIONS[fr_STEP_GLPI_READY]="GLPI extrait !"
    
    TRANSLATIONS[fr_SECURITY_TITLE]="Sécurisation du système"
    TRANSLATIONS[fr_SECURITY_MDB]="Sécurisation de MariaDB..."
    TRANSLATIONS[fr_SECURITY_GLPI]="Sécurisation des répertoires GLPI..."
    TRANSLATIONS[fr_SECURITY_FIREWALL]="Configuration du pare-feu..."
    TRANSLATIONS[fr_FIREWALL_PROMPT]="Souhaitez-vous configurer le pare-feu (UFW) ?\n\nCela autorisera uniquement les ports 22 (SSH), 80 (HTTP) et 443 (HTTPS)."
    TRANSLATIONS[fr_FIREWALL_CONFIGURED]="Pare-feu configuré avec succès !"
    TRANSLATIONS[fr_FIREWALL_SKIPPED]="Configuration du pare-feu ignorée."
    TRANSLATIONS[fr_ROOT_PASS_TITLE]="Mot de passe root MySQL"
    TRANSLATIONS[fr_ROOT_PASS_PROMPT]="Entrez un mot de passe fort pour le root MySQL :"
    TRANSLATIONS[fr_ROOT_PASS_CONFIRM]="Confirmez le mot de passe root MySQL :"
    TRANSLATIONS[fr_ROOT_PASS_SAVED]="Mot de passe root MySQL sauvegardé dans : /root/.mysql_credentials"
    
    # Finalisation
    TRANSLATIONS[fr_INSTALL_COMPLETE]="Installation terminée"
    TRANSLATIONS[fr_SUCCESS_MSG]="GLPI installé avec succès !\n\nURL: https://%s/\nIP: %s\n\nBase de données: %s\nUtilisateur DB: %s\nMot de passe DB: %s\n\nIdentifiants GLPI par défaut:\nUtilisateur: glpi\nMot de passe: glpi\n\n⚠️ CHANGEZ-LES IMMÉDIATEMENT !"
    TRANSLATIONS[fr_UNINSTALL_TITLE]="Désinstallation"
    TRANSLATIONS[fr_UNINSTALL_PROMPT]="Souhaitez-vous créer un script de désinstallation automatique ?"
    TRANSLATIONS[fr_UNINSTALL_CREATED]="Script de désinstallation créé : ./uninstall-glpi.sh"
    TRANSLATIONS[fr_TEST_TITLE]="Tests de vérification"
    TRANSLATIONS[fr_TEST_PROMPT]="Souhaitez-vous exécuter quelques tests pour vérifier l'installation ?"
    TRANSLATIONS[fr_TEST_RESULTS]="Résultats des tests"
    TRANSLATIONS[fr_APACHE_RUNNING]="Apache actif"
    TRANSLATIONS[fr_APACHE_STOPPED]="Apache arrêté"
    TRANSLATIONS[fr_MDB_RUNNING]="MariaDB actif"
    TRANSLATIONS[fr_MDB_STOPPED]="MariaDB arrêté"
    TRANSLATIONS[fr_GLPI_OK]="Répertoire GLPI : OK"
    TRANSLATIONS[fr_GLPI_MISSING]="Répertoire GLPI manquant"
    TRANSLATIONS[fr_UNINSTALL_MSG]="GLPI et ses composants ont été supprimés."
    
    # Erreurs
    TRANSLATIONS[fr_ERROR_UPDATE]="Erreur lors de la mise à jour des paquets"
    TRANSLATIONS[fr_ERROR_WEBSERVER]="Erreur lors de l'installation du serveur web"
    TRANSLATIONS[fr_ERROR_PHP]="Erreur lors de l'installation de PHP"
    TRANSLATIONS[fr_ERROR_TOOLS]="Erreur lors de l'installation des outils"
    TRANSLATIONS[fr_ERROR_CREATE_DB]="Erreur lors de la création de la base de données"
    TRANSLATIONS[fr_ERROR_DOWNLOAD]="Erreur lors du téléchargement de GLPI"
    TRANSLATIONS[fr_ERROR_EXTRACT]="Erreur lors de l'extraction de GLPI"
    TRANSLATIONS[fr_ERROR_RESTART_MDB]="Erreur lors du redémarrage de MariaDB"
    TRANSLATIONS[fr_ERROR_APACHE]="Erreur lors du rechargement d'Apache"
    
    # === ENGLISH ===
    TRANSLATIONS[en_ERROR_TITLE]="Error"
    TRANSLATIONS[en_SCRIPT_STOP]="The script will stop."
    TRANSLATIONS[en_ROOT_CHECK]="This script must be run with sudo or as root."
    TRANSLATIONS[en_INSTALL_CANCEL]="Installation cancelled by the user."
    TRANSLATIONS[en_NO_INTERNET]="No Internet connection"
    
    # Menus and titles
    TRANSLATIONS[en_LANG_TITLE]="Language Selection"
    TRANSLATIONS[en_LANG_PROMPT]="Choose your language:"
    TRANSLATIONS[en_INSTALL_TITLE]="GLPI Installation"
    TRANSLATIONS[en_CONTINUE_PROMPT]="This script performs an automatic GLPI installation.\nDo you want to continue?"
    
    # Database
    TRANSLATIONS[en_DB_TITLE]="Database"
    TRANSLATIONS[en_DB_NAME_PROMPT]="Enter the MySQL database name:"
    TRANSLATIONS[en_DB_USER_TITLE]="MySQL User"
    TRANSLATIONS[en_DB_USER_PROMPT]="Enter the MySQL username:"
    TRANSLATIONS[en_DB_PASS_TITLE]="MySQL Password"
    TRANSLATIONS[en_DB_PASS_GEN]="Do you want to automatically generate a strong password for the user"
    TRANSLATIONS[en_DB_PASS_GENERATED]="Automatically generated MySQL password:\n\n"
    TRANSLATIONS[en_DB_PASS_ENTER]="Enter password for"
    TRANSLATIONS[en_DB_PASS_CONFIRM]="Confirm Password"
    TRANSLATIONS[en_DB_PASS_REENTER]="Re-enter password for verification:"
    TRANSLATIONS[en_DB_PASS_MISMATCH]="Password mismatch"
    TRANSLATIONS[en_DB_PASS_NOMATCH]="The two passwords do not match.\n\nPlease try again."
    
    # MariaDB Security
    TRANSLATIONS[en_MDB_SECURITY_TITLE]="MariaDB Security"
    TRANSLATIONS[en_MDB_WARNING]="SECURITY WARNING!\n\nMariaDB will be configured to listen on all interfaces (0.0.0.0).\n\nThis means your database will be accessible from the network.\n\nMake sure that:\n• Your firewall is properly configured\n• Port 3306 is NOT exposed to the Internet\n• You are using a strong password\n\nDo you really want to enable remote access?"
    TRANSLATIONS[en_MDB_LOCAL_ONLY]="MariaDB will remain accessible only locally (127.0.0.1).\n\nFor remote access later, manually edit:\n/etc/mysql/mariadb.conf.d/50-server.cnf"
    
    # SSL
    TRANSLATIONS[en_SSL_TITLE]="HTTPS Certificate"
    TRANSLATIONS[en_DOMAIN_PROMPT]="Enter your domain or server IP:"
    TRANSLATIONS[en_SSL_CREATE]="Do you want to create a self-signed HTTPS certificate for"
    TRANSLATIONS[en_SSL_DAYS_TITLE]="Certificate duration"
    TRANSLATIONS[en_SSL_DAYS_PROMPT]="Days valid:"
    
    # Progress messages
    TRANSLATIONS[en_UPDATE_DEPS]="Updating packages and installing dependencies..."
    TRANSLATIONS[en_SETUP_DB]="Setting up database"
    TRANSLATIONS[en_DOWNLOAD_GLPI]="Downloading and extracting GLPI..."
    TRANSLATIONS[en_STEP_UPDATE]="Updating package lists..."
    TRANSLATIONS[en_STEP_APACHE]="Installing Apache & MariaDB..."
    TRANSLATIONS[en_STEP_PHP]="Installing PHP 8.2 extensions..."
    TRANSLATIONS[en_STEP_UTILS]="Installing utilities..."
    TRANSLATIONS[en_STEP_COMPLETE]="Dependencies installed!"
    TRANSLATIONS[en_STEP_CREATE_DB]="Creating database..."
    TRANSLATIONS[en_STEP_DROP_USERS]="Removing old users..."
    TRANSLATIONS[en_STEP_CREATE_USERS]="Creating MySQL users..."
    TRANSLATIONS[en_STEP_GRANT]="Granting privileges..."
    TRANSLATIONS[en_STEP_DB_READY]="Database ready!"
    TRANSLATIONS[en_STEP_FETCH_VERSION]="Fetching latest GLPI version..."
    TRANSLATIONS[en_STEP_DOWNLOADING]="Downloading GLPI archive..."
    TRANSLATIONS[en_STEP_EXTRACTING]="Extracting files..."
    TRANSLATIONS[en_STEP_MOVING]="Moving files..."
    TRANSLATIONS[en_STEP_GLPI_READY]="GLPI extracted!"
    
    # Finalization
    TRANSLATIONS[en_INSTALL_COMPLETE]="Installation Complete"
    TRANSLATIONS[en_SUCCESS_MSG]="GLPI installed successfully!\n\nURL: https://%s/\nIP: %s\n\nDatabase: %s\nDB User: %s\nDB Password: %s\n\nDefault GLPI credentials:\nUser: glpi\nPassword: glpi\n\n⚠️ CHANGE THEM IMMEDIATELY!"
    TRANSLATIONS[en_UNINSTALL_TITLE]="Uninstall"
    TRANSLATIONS[en_UNINSTALL_PROMPT]="Do you want to create an automatic uninstall script?"
    TRANSLATIONS[en_UNINSTALL_CREATED]="Uninstall script created: ./uninstall-glpi.sh"
    TRANSLATIONS[en_TEST_TITLE]="Verification Tests"
    TRANSLATIONS[en_TEST_PROMPT]="Do you want to run some tests to verify the installation?"
    TRANSLATIONS[en_TEST_RESULTS]="Test Results"
    TRANSLATIONS[en_APACHE_RUNNING]="Apache running"
    TRANSLATIONS[en_APACHE_STOPPED]="Apache stopped"
    TRANSLATIONS[en_MDB_RUNNING]="MariaDB running"
    TRANSLATIONS[en_MDB_STOPPED]="MariaDB stopped"
    TRANSLATIONS[en_GLPI_OK]="GLPI directory exists"
    TRANSLATIONS[en_GLPI_MISSING]="GLPI directory missing"
    TRANSLATIONS[en_UNINSTALL_MSG]="GLPI and its components have been removed."
    
    TRANSLATIONS[en_SECURITY_TITLE]="System Hardening"
    TRANSLATIONS[en_SECURITY_MDB]="Securing MariaDB..."
    TRANSLATIONS[en_SECURITY_GLPI]="Securing GLPI directories..."
    TRANSLATIONS[en_SECURITY_FIREWALL]="Configuring firewall..."
    TRANSLATIONS[en_FIREWALL_PROMPT]="Do you want to configure the firewall (UFW)?\n\nThis will only allow ports 22 (SSH), 80 (HTTP) and 443 (HTTPS)."
    TRANSLATIONS[en_FIREWALL_CONFIGURED]="Firewall configured successfully!"
    TRANSLATIONS[en_FIREWALL_SKIPPED]="Firewall configuration skipped."
    TRANSLATIONS[en_ROOT_PASS_TITLE]="MySQL root password"
    TRANSLATIONS[en_ROOT_PASS_PROMPT]="Enter a strong password for MySQL root:"
    TRANSLATIONS[en_ROOT_PASS_CONFIRM]="Confirm MySQL root password:"
    TRANSLATIONS[en_ROOT_PASS_SAVED]="MySQL root password saved in: /root/.mysql_credentials"
    
    # Errors
    TRANSLATIONS[en_ERROR_UPDATE]="Error updating packages"
    TRANSLATIONS[en_ERROR_WEBSERVER]="Error installing web server"
    TRANSLATIONS[en_ERROR_PHP]="Error installing PHP"
    TRANSLATIONS[en_ERROR_TOOLS]="Error installing tools"
    TRANSLATIONS[en_ERROR_CREATE_DB]="Error creating database"
    TRANSLATIONS[en_ERROR_DOWNLOAD]="Error downloading GLPI"
    TRANSLATIONS[en_ERROR_EXTRACT]="Error extracting GLPI"
    TRANSLATIONS[en_ERROR_RESTART_MDB]="Error restarting MariaDB"
    TRANSLATIONS[en_ERROR_APACHE]="Error reloading Apache"
}

# Fonction de traduction
t() {
    local key="${LANG}_${1}"
    echo "${TRANSLATIONS[$key]}"
}

error_exit() {
    whiptail --title "$(t ERROR_TITLE)" --msgbox "$1\n\n$(t SCRIPT_STOP)" 12 60
    exit 1
}

# --- Fix locales ---
apt-get update -y
apt-get install -y locales
locale-gen en_US.UTF-8 fr_FR.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- Language selection ---
LANG_CHOICE=$(whiptail --title "Language Selection / Choix de la langue" --menu "Choose your language / Choisissez votre langue :" 15 60 2 \
  "fr" "Français" \
  "en" "English" \
  3>&1 1>&2 2>&3) || error_exit "Installation cancelled / Installation annulée."

LANG="$LANG_CHOICE"
init_translations

# --- Check root ---
[[ $EUID -ne 0 ]] && error_exit "$(t ROOT_CHECK)"

# --- Confirm continuation ---
whiptail --title "$(t INSTALL_TITLE)" --yesno "$(t CONTINUE_PROMPT)" 16 70 || error_exit "$(t INSTALL_CANCEL)"

# --- Test Internet connection ---
wget -q --spider https://google.com || error_exit "$(t NO_INTERNET)"

# --- Get server IP ---
IP_MACHINE=$(hostname -I | awk '{print $1}')

# --- Update & install dependencies ---
{
  echo "XXX"
  echo "0"
  echo "$(t STEP_UPDATE)"
  echo "XXX"
  apt-get update -y > /tmp/apt-update.log 2>&1 || error_exit "$(t ERROR_UPDATE)"
  
  echo "XXX"
  echo "25"
  echo "$(t STEP_APACHE)"
  echo "XXX"
  apt-get install -y apache2 mariadb-server > /tmp/apt-install1.log 2>&1 || error_exit "$(t ERROR_WEBSERVER)"
  
  echo "XXX"
  echo "50"
  echo "$(t STEP_PHP)"
  echo "XXX"
  apt-get install -y php8.2 php8.2-mysql php8.2-xml php8.2-mbstring php8.2-curl php8.2-gd php8.2-intl php8.2-ldap php8.2-imap php8.2-zip php8.2-bz2 php8.2-cli php8.2-apcu php8.2-bcmath php8.2-opcache php8.2-exif > /tmp/apt-install2.log 2>&1 || error_exit "$(t ERROR_PHP)"
  
  echo "XXX"
  echo "75"
  echo "$(t STEP_UTILS)"
  echo "XXX"
  apt-get install -y unzip wget tar dialog whiptail curl openssl locales-all > /tmp/apt-install3.log 2>&1 || error_exit "$(t ERROR_TOOLS)"
  
  echo "XXX"
  echo "100"
  echo "$(t STEP_COMPLETE)"
  echo "XXX"
  sleep 0.5
} | whiptail --gauge "$(t UPDATE_DEPS)" 8 70 0

# --- Database input ---
# Validation des entrées pour éviter l'injection SQL
while true; do
  DB_NAME=$(whiptail --title "$(t DB_TITLE)" --inputbox "$(t DB_NAME_PROMPT)" 10 60 "glpidb" 3>&1 1>&2 2>&3)
  if [[ "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    break
  else
    whiptail --msgbox "Invalid database name. Only alphanumeric and underscore allowed.\nNom invalide. Seulement alphanumérique et underscore." 10 60
  fi
done

while true; do
  DB_USER=$(whiptail --title "$(t DB_USER_TITLE)" --inputbox "$(t DB_USER_PROMPT)" 10 60 "glpiuser" 3>&1 1>&2 2>&3)
  if [[ "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    break
  else
    whiptail --msgbox "Invalid username. Only alphanumeric and underscore allowed.\nNom invalide. Seulement alphanumérique et underscore." 10 60
  fi
done

# --- Password ---
if whiptail --title "$(t DB_PASS_TITLE)" --yesno "$(t DB_PASS_GEN) $DB_USER ?" 10 60; then
  DB_PASS=$(openssl rand -base64 16 | tr -d '=+/[:space:]' | cut -c1-16)
  whiptail --title "$(t DB_PASS_TITLE)" --msgbox "$(t DB_PASS_GENERATED)$DB_PASS" 12 60
else
  while true; do
    DB_PASS1=$(whiptail --title "$(t DB_PASS_TITLE)" \
      --passwordbox "$(t DB_PASS_ENTER) $DB_USER :" 10 60 3>&1 1>&2 2>&3)
    DB_PASS2=$(whiptail --title "$(t DB_PASS_CONFIRM)" \
      --passwordbox "$(t DB_PASS_REENTER)" 10 60 3>&1 1>&2 2>&3)
    if [ "$DB_PASS1" = "$DB_PASS2" ] && [ -n "$DB_PASS1" ]; then
      DB_PASS="$DB_PASS1"
      break
    else
      whiptail --title "$(t DB_PASS_MISMATCH)" --msgbox "$(t DB_PASS_NOMATCH)" 12 70
    fi
  done
fi

# --- Create DB & user ---
{
  echo "XXX"
  echo "10"
  echo "$(t STEP_CREATE_DB)"
  echo "XXX"
  mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || error_exit "$(t ERROR_CREATE_DB)"
  
  echo "XXX"
  echo "40"
  echo "$(t STEP_DROP_USERS)"
  echo "XXX"
  mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
  mysql -e "DROP USER IF EXISTS '$DB_USER'@'%';"
  
  echo "XXX"
  echo "60"
  echo "$(t STEP_CREATE_USERS)"
  echo "XXX"
  mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
  mysql -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';"
  
  echo "XXX"
  echo "80"
  echo "$(t STEP_GRANT)"
  echo "XXX"
  mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
  mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';"
  mysql -e "FLUSH PRIVILEGES;"
  
  echo "XXX"
  echo "100"
  echo "$(t STEP_DB_READY)"
  echo "XXX"
  sleep 0.5
} | whiptail --gauge "$(t SETUP_DB)" 8 70 0

# --- Sécurisation de MariaDB ---
{
  echo "XXX"
  echo "20"
  echo "$(t SECURITY_MDB)"
  echo "XXX"
  
  # Définir un mot de passe root MySQL
  while true; do
    MYSQL_ROOT_PASS1=$(whiptail --title "$(t ROOT_PASS_TITLE)" \
      --passwordbox "$(t ROOT_PASS_PROMPT)" 10 60 3>&1 1>&2 2>&3)
    MYSQL_ROOT_PASS2=$(whiptail --title "$(t ROOT_PASS_TITLE)" \
      --passwordbox "$(t ROOT_PASS_CONFIRM)" 10 60 3>&1 1>&2 2>&3)
    if [ "$MYSQL_ROOT_PASS1" = "$MYSQL_ROOT_PASS2" ] && [ -n "$MYSQL_ROOT_PASS1" ]; then
      MYSQL_ROOT_PASS="$MYSQL_ROOT_PASS1"
      break
    else
      whiptail --msgbox "$(t DB_PASS_NOMATCH)" 10 60
    fi
  done
  
  echo "XXX"
  echo "50"
  echo "$(t SECURITY_MDB)"
  echo "XXX"
  
  # Sécuriser MariaDB
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
  mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='';"
  mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
  mysql -u root -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS test;"
  mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
  mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"
  
  # Sauvegarder les credentials de manière sécurisée
  cat > /root/.mysql_credentials << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
  chmod 600 /root/.mysql_credentials
  
  echo "XXX"
  echo "100"
  echo "$(t ROOT_PASS_SAVED)"
  echo "XXX"
  sleep 1
} | whiptail --gauge "$(t SECURITY_TITLE)" 8 70 0

# --- Bind MariaDB to all interfaces (avec avertissement) ---
if whiptail --title "$(t MDB_SECURITY_TITLE)" --yesno "$(t MDB_WARNING)" 20 70; then
  sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
  systemctl restart mariadb || error_exit "$(t ERROR_RESTART_MDB)"
else
  sed -i "s/^bind-address\s*=.*/bind-address = 127.0.0.1/" /etc/mysql/mariadb.conf.d/50-server.cnf
  systemctl restart mariadb || error_exit "$(t ERROR_RESTART_MDB)"
  whiptail --msgbox "$(t MDB_LOCAL_ONLY)" 12 70
fi

# --- Téléchargement et extraction de GLPI ---
GLPI_DIR="/var/www/html/glpi"
GLPI_ARCHIVE="/tmp/glpi.tgz"
rm -f "$GLPI_ARCHIVE"

GLPI_URL=$(wget -qO- https://api.github.com/repos/glpi-project/glpi/releases/latest \
            | grep browser_download_url \
            | grep glpi.tgz \
            | cut -d '"' -f 4)

if [[ -z "$GLPI_URL" ]]; then
  GLPI_URL="https://github.com/glpi-project/glpi/releases/download/11.0.0/glpi-11.0.0.tgz"
fi

{
  echo "XXX"
  echo "5"
  echo "$(t STEP_FETCH_VERSION)"
  echo "XXX"
  
  echo "XXX"
  echo "15"
  echo "$(t STEP_DOWNLOADING)"
  echo "XXX"
  wget --progress=dot "$GLPI_URL" -O "$GLPI_ARCHIVE" 2>&1 | \
    grep --line-buffered "%" | \
    sed -u -e "s,\.,,g" | \
    awk '{printf("XXX\n%d\n'"$(t STEP_DOWNLOADING)"': %s\nXXX\n", 15+$2*0.6, $7)}' || error_exit "$(t ERROR_DOWNLOAD)"
  
  echo "XXX"
  echo "75"
  echo "$(t STEP_EXTRACTING)"
  echo "XXX"
  tar -xzf "$GLPI_ARCHIVE" -C /var/www/html/ || error_exit "$(t ERROR_EXTRACT)"
  
  echo "XXX"
  echo "90"
  echo "$(t STEP_MOVING)"
  echo "XXX"
  mv /var/www/html/glpi-* "$GLPI_DIR" 2>/dev/null || true
  
  echo "XXX"
  echo "100"
  echo "$(t STEP_GLPI_READY)"
  echo "XXX"
  sleep 0.5
} | whiptail --gauge "$(t DOWNLOAD_GLPI)" 8 70 0

# Permissions sécurisées
chown -R www-data:www-data "$GLPI_DIR"
chmod -R 750 "$GLPI_DIR"
chmod -R 770 "$GLPI_DIR/files"
chmod -R 770 "$GLPI_DIR/config"

# Déplacer les répertoires sensibles hors de public/
mkdir -p /var/lib/glpi
if [ -d "$GLPI_DIR/files" ]; then
  mv "$GLPI_DIR/files" /var/lib/glpi/ 2>/dev/null || true
  ln -s /var/lib/glpi/files "$GLPI_DIR/files"
fi
if [ -d "$GLPI_DIR/config" ]; then
  mv "$GLPI_DIR/config" /var/lib/glpi/ 2>/dev/null || true
  ln -s /var/lib/glpi/config "$GLPI_DIR/config"
fi
chown -R www-data:www-data /var/lib/glpi

cat << EOF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    DocumentRoot $GLPI_DIR/public
    <Directory $GLPI_DIR/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# --- SSL setup ---
DOMAIN=$(whiptail --title "$(t SSL_TITLE)" --inputbox "$(t DOMAIN_PROMPT)" 10 60 "$IP_MACHINE" 3>&1 1>&2 2>&3)
if whiptail --title "$(t SSL_TITLE)" --yesno "$(t SSL_CREATE) $DOMAIN ?" 10 60; then
  SSL_DIR="/etc/ssl/glpi"
  mkdir -p "$SSL_DIR"
  CERT_DAYS=$(whiptail --title "$(t SSL_DAYS_TITLE)" --inputbox "$(t SSL_DAYS_PROMPT)" 10 60 "365" 3>&1 1>&2 2>&3)
  openssl req -x509 -nodes -days "$CERT_DAYS" -newkey rsa:2048 \
    -keyout "$SSL_DIR/glpi.key" \
    -out "$SSL_DIR/glpi.crt" \
    -subj "/C=FR/ST=France/L=Local/O=GLPI/CN=$DOMAIN"
  cat << EOF > /etc/apache2/sites-available/glpi-ssl.conf
<VirtualHost *:443>
    DocumentRoot $GLPI_DIR/public
    <Directory $GLPI_DIR/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile $SSL_DIR/glpi.crt
    SSLCertificateKeyFile $SSL_DIR/glpi.key
</VirtualHost>
EOF
  a2enmod ssl
  a2ensite glpi-ssl.conf
fi

# --- Enable site & modules ---
a2ensite glpi.conf
a2enmod rewrite
systemctl reload apache2 || error_exit "$(t ERROR_APACHE)"

# --- PHP configuration ---
PHP_INI="/etc/php/8.2/apache2/php.ini"
sed -i "s/^;*session.cookie_httponly\s*=.*/session.cookie_httponly = On/" "$PHP_INI"
sed -i "s/^;*session.cookie_secure\s*=.*/session.cookie_secure = On/" "$PHP_INI"
[ "$LANG" = "fr" ] && sed -i "s/^;*intl.default_locale\s*=.*/intl.default_locale = fr_FR/" "$PHP_INI" || sed -i "s/^;*intl.default_locale\s*=.*/intl.default_locale = en_US/" "$PHP_INI"
systemctl reload apache2

# --- Create .htaccess ---
cat << 'EOF' > "$GLPI_DIR/public/.htaccess"
<IfModule mod_rewrite.c>
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

# Sécurité: Empêcher l'accès aux fichiers sensibles
<FilesMatch "\.(htaccess|htpasswd|ini|log|sh|sql|conf|bak)$">
   Require all denied
</FilesMatch>
EOF

# Bloquer l'accès direct aux répertoires sensibles
cat << 'EOF' > "$GLPI_DIR/install/.htaccess"
Require all denied
EOF

cat << 'EOF' > "$GLPI_DIR/files/.htaccess"
Require all denied
EOF

cat << 'EOF' > "$GLPI_DIR/config/.htaccess"
Require all denied
EOF

# --- Finished ---
# Nettoyer les logs sensibles
sed -i "s/$DB_PASS/***HIDDEN***/g" "$LOGFILE" 2>/dev/null || true
sed -i "s/$MYSQL_ROOT_PASS/***HIDDEN***/g" "$LOGFILE" 2>/dev/null || true

FINAL_MSG=$(printf "$(t SUCCESS_MSG)" "$DOMAIN" "$IP_MACHINE" "$DB_NAME" "$DB_USER" "$DB_PASS")
whiptail --title "$(t INSTALL_COMPLETE)" --msgbox "$FINAL_MSG" 20 70

# --- Désinstallateur intégré ---
if whiptail --title "$(t UNINSTALL_TITLE)" --yesno "$(t UNINSTALL_PROMPT)" 10 60; then
cat << REMOVE > uninstall-glpi.sh
#!/bin/bash
export PATH=\$PATH:/usr/sbin:/sbin

# Remove GLPI files
rm -rf "$GLPI_DIR" "$GLPI_ARCHIVE" /var/lib/glpi

# Remove Apache configs
rm -f /etc/apache2/sites-available/glpi.conf /etc/apache2/sites-available/glpi-ssl.conf
rm -rf /etc/ssl/glpi

# Disable Apache sites
/usr/sbin/a2dissite glpi.conf 2>/dev/null
/usr/sbin/a2dissite glpi-ssl.conf 2>/dev/null
systemctl reload apache2

# Drop MySQL database and users (requires root password)
if [ -f /root/.mysql_credentials ]; then
  mysql --defaults-file=/root/.mysql_credentials -e "DROP DATABASE IF EXISTS $DB_NAME;"
  mysql --defaults-file=/root/.mysql_credentials -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
  mysql --defaults-file=/root/.mysql_credentials -e "DROP USER IF EXISTS '$DB_USER'@'%';"
else
  echo "Warning: Could not find MySQL credentials file"
  echo "Please manually drop database '$DB_NAME' and user '$DB_USER'"
fi

echo "$(t UNINSTALL_MSG)"
REMOVE

chmod +x uninstall-glpi.sh
whiptail --msgbox "$(t UNINSTALL_CREATED)" 10 60
fi

# --- Test menu ---
if whiptail --title "$(t TEST_TITLE)" --yesno "$(t TEST_PROMPT)" 10 60; then
  APACHE_STATUS=$(systemctl is-active apache2 && echo "$(t APACHE_RUNNING)" || echo "$(t APACHE_STOPPED)")
  MDB_STATUS=$(systemctl is-active mariadb && echo "$(t MDB_RUNNING)" || echo "$(t MDB_STOPPED)")
  GLPI_STATUS=$( [ -d "$GLPI_DIR" ] && echo "$(t GLPI_OK)" || echo "$(t GLPI_MISSING)" )
  whiptail --title "$(t TEST_RESULTS)" --msgbox "$APACHE_STATUS\n$MDB_STATUS\n$GLPI_STATUS" 12 60
fi
