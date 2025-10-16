#!/bin/bash
# Interactive GLPI installation script for Debian 12
# Author: Alexandre

export PATH=$PATH:/usr/sbin:/sbin
LOGFILE="/var/log/glpi-install.log"
exec > >(tee -i "$LOGFILE") 2>&1

error_exit() {
    whiptail --title "Error / Erreur" --msgbox "Error: $1\nErreur : $1\n\nThe script will stop.\nLe script s'arrête." 12 60
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
  "1" "Français" \
  "2" "English" \
  3>&1 1>&2 2>&3) || error_exit "Installation cancelled / Installation annulée."
[[ "$LANG_CHOICE" = "1" ]] && LANG="fr" || LANG="en"

# --- Messages ---
if [ "$LANG" = "fr" ]; then
  MSG_ROOT_CHECK="Ce script doit être exécuté avec sudo ou en tant que root."
  MSG_INSTALL_CANCEL="Installation annulée par l'utilisateur."
  MSG_UPDATE_DEPS="Mise à jour des paquets et installation des dépendances..."
  MSG_CONTINUE_INSTALL="Ce script effectue une installation automatique de GLPI.\nSouhaitez-vous continuer ?"
  MSG_DB_NAME="Entrez le nom de la base MySQL :"
  MSG_DB_USER="Entrez le nom d'utilisateur MySQL :"
  MSG_GEN_PASS_PROMPT="Souhaitez-vous générer un mot de passe fort pour l'utilisateur"
  MSG_DB_PASS_GEN_MSG="Mot de passe MySQL généré automatiquement :\n\n"
  MSG_SECURE_MDB="Vous allez maintenant sécuriser MariaDB."
  MSG_DOWNLOAD_GLPI="Téléchargement et extraction de GLPI..."
  MSG_SSL_CERT_PROMPT="Voulez-vous créer un certificat HTTPS auto-signé pour"
  MSG_UNINSTALL_PROMPT="Souhaitez-vous créer un script de désinstallation automatique ?"
  MSG_UNINSTALL_SCRIPT="Script créé : ./uninstall-glpi.sh"
  MSG_TEST_MENU="Souhaitez-vous exécuter quelques tests pour vérifier l'installation ?"
  MSG_TEST_RESULTS="Tests effectués avec succès !"
else
  MSG_ROOT_CHECK="This script must be run with sudo or as root."
  MSG_INSTALL_CANCEL="Installation cancelled by the user."
  MSG_UPDATE_DEPS="Updating packages and installing dependencies..."
  MSG_CONTINUE_INSTALL="This script performs an automatic GLPI installation.\nDo you want to continue?"
  MSG_DB_NAME="Enter the MySQL database name:"
  MSG_DB_USER="Enter the MySQL username:"
  MSG_GEN_PASS_PROMPT="Do you want to automatically generate a strong password for the user"
  MSG_DB_PASS_GEN_MSG="Automatically generated MySQL password:\n\n"
  MSG_SECURE_MDB="You will now secure MariaDB."
  MSG_DOWNLOAD_GLPI="Downloading and extracting GLPI..."
  MSG_SSL_CERT_PROMPT="Do you want to create a self-signed HTTPS certificate for"
  MSG_UNINSTALL_PROMPT="Do you want to create an automatic uninstall script?"
  MSG_UNINSTALL_SCRIPT="Script created: ./uninstall-glpi.sh"
  MSG_TEST_MENU="Do you want to run some tests to verify the installation?"
  MSG_TEST_RESULTS="Tests completed successfully!"
fi

# --- Check root ---
[[ $EUID -ne 0 ]] && error_exit "$MSG_ROOT_CHECK"

# --- Confirm continuation ---
whiptail --title "GLPI Installation" --yesno "$MSG_CONTINUE_INSTALL" 16 70 || error_exit "$MSG_INSTALL_CANCEL"

# --- Test Internet connection ---
wget -q --spider https://google.com || error_exit "No Internet / Pas de connexion Internet"

# --- Get server IP ---
IP_MACHINE=$(hostname -I | awk '{print $1}')

# --- Update & install dependencies ---
(
  echo 10; sleep 0.3
  apt-get update -y || error_exit "Error updating packages / Erreur update"
  echo 30; sleep 0.3
  apt-get install -y apache2 mariadb-server \
    php8.2 php8.2-mysql php8.2-xml php8.2-mbstring php8.2-curl php8.2-gd php8.2-intl php8.2-ldap php8.2-imap php8.2-zip php8.2-bz2 php8.2-cli php8.2-apcu \
    unzip wget tar dialog whiptail curl openssl locales-all || error_exit "Error installing dependencies / Erreur installation dépendances"
  echo 60; sleep 0.3
) | whiptail --gauge "$MSG_UPDATE_DEPS" 6 60 0

# --- Database input ---
DB_NAME=$(whiptail --title "Database / Base de données" --inputbox "$MSG_DB_NAME" 10 60 "glpidb" 3>&1 1>&2 2>&3)
DB_USER=$(whiptail --title "MySQL User" --inputbox "$MSG_DB_USER" 10 60 "glpiuser" 3>&1 1>&2 2>&3)

# --- Password ---
if whiptail --title "MySQL Password" --yesno "$MSG_GEN_PASS_PROMPT $DB_USER ?" 10 60; then
  # Génération automatique d’un mot de passe fort
  DB_PASS=$(openssl rand -base64 16 | tr -d '=+/[:space:]' | cut -c1-16)
  whiptail --title "MySQL Password / Mot de passe MySQL" \
    --msgbox "$MSG_DB_PASS_GEN_MSG$DB_PASS" 12 60
else
  # Double saisie manuelle du mot de passe
  while true; do
    DB_PASS1=$(whiptail --title "MySQL Password / Mot de passe MySQL" \
      --passwordbox "Enter password for $DB_USER / Entrez le mot de passe pour $DB_USER :" 10 60 3>&1 1>&2 2>&3)

    DB_PASS2=$(whiptail --title "Confirm Password / Confirmez le mot de passe" \
      --passwordbox "Re-enter password / Ressaisissez le mot de passe pour vérification :" 10 60 3>&1 1>&2 2>&3)

    if [ "$DB_PASS1" = "$DB_PASS2" ] && [ -n "$DB_PASS1" ]; then
      DB_PASS="$DB_PASS1"
      break
    else
      whiptail --title "Password mismatch / Mot de passe différent" \
        --msgbox "The two passwords do not match.\nLes deux mots de passe ne correspondent pas.\n\nPlease try again / Veuillez réessayer." 12 70
    fi
  done
fi


# --- Create DB & user ---
(
  echo 70; sleep 0.2
  mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || error_exit "Error creating DB / Erreur création DB"
  mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
  mysql -e "DROP USER IF EXISTS '$DB_USER'@'%';"
  mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
  mysql -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';"
  mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
  mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';"
  mysql -e "FLUSH PRIVILEGES;"
  echo 80; sleep 0.3
) | whiptail --gauge "Creating database / Création base de données" 6 60 0

# --- Bind MariaDB to all interfaces ---
sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb || error_exit "Restart MariaDB failed / Erreur redémarrage MariaDB"

# --- Téléchargement et extraction de GLPI (silencieux) ---
GLPI_DIR="/var/www/html/glpi"
GLPI_ARCHIVE="/tmp/glpi.tgz"

rm -f "$GLPI_ARCHIVE"

# Récupération URL dernière version GLPI
GLPI_URL=$(wget -qO- https://api.github.com/repos/glpi-project/glpi/releases/latest \
            | grep browser_download_url \
            | grep glpi.tgz \
            | cut -d '"' -f 4)

# Si pas d'URL trouvée, fallback sur une version par défaut
if [[ -z "$GLPI_URL" ]]; then
  GLPI_URL="https://github.com/glpi-project/glpi/releases/download/11.0.0/glpi-11.0.0.tgz"
fi

# Téléchargement + extraction avec barre de progression
(
  echo 10; sleep 0.3
  wget -q "$GLPI_URL" -O "$GLPI_ARCHIVE" || error_exit "Error downloading GLPI / Erreur téléchargement GLPI"
  echo 50; sleep 0.3
  tar -xzf "$GLPI_ARCHIVE" -C /var/www/html/ || error_exit "Error extracting GLPI / Erreur extraction GLPI"
  mv /var/www/html/glpi-* "$GLPI_DIR"
  echo 100; sleep 0.3
) | whiptail --gauge "$MSG_DOWNLOAD_GLPI" 6 60 0

# Permissions
chown -R www-data:www-data "$GLPI_DIR"
chmod -R 755 "$GLPI_DIR"


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
DOMAIN=$(whiptail --title "Domain / Domaine" --inputbox "Enter your domain or server IP / Entrez le domaine ou l'IP :" 10 60 "$IP_MACHINE" 3>&1 1>&2 2>&3)
if whiptail --title "Self-signed HTTPS" --yesno "$MSG_SSL_CERT_PROMPT $DOMAIN ?" 10 60; then
  SSL_DIR="/etc/ssl/glpi"
  mkdir -p "$SSL_DIR"
  CERT_DAYS=$(whiptail --title "Certificate duration" --inputbox "Days valid / Durée (jours) :" 10 60 "365" 3>&1 1>&2 2>&3)
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
systemctl reload apache2 || error_exit "Apache reload failed / Erreur reload Apache"

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
EOF

# --- Finished ---
whiptail --title "Installation terminée / Finished" --msgbox "GLPI installed successfully / GLPI installé !\n\nURL: https://$DOMAIN/\nIP: $IP_MACHINE\nDB user: $DB_USER" 14 60

# --- Désinstallateur intégré ---
if whiptail --title "Uninstall / Désinstaller" --yesno "$MSG_UNINSTALL_PROMPT" 10 60; then
cat << REMOVE > uninstall-glpi.sh
#!/bin/bash
export PATH=\$PATH:/usr/sbin:/sbin

# Remove GLPI files
rm -rf "$GLPI_DIR" "$GLPI_ARCHIVE"

# Remove Apache configs
rm -f /etc/apache2/sites-available/glpi.conf /etc/apache2/sites-available/glpi-ssl.conf

# Disable Apache sites
/usr/sbin/a2dissite glpi.conf
/usr/sbin/a2dissite glpi-ssl.conf
systemctl reload apache2

# Drop MySQL database and users
mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'%';"

echo "GLPI et ses composants ont été supprimés / GLPI and its components have been removed."
REMOVE

chmod +x uninstall-glpi.sh
whiptail --msgbox "$MSG_UNINSTALL_SCRIPT" 10 60
fi


# --- Test menu ---
if whiptail --title "Test Menu / Vérification" --yesno "$MSG_TEST_MENU" 10 60; then
  APACHE_STATUS=$(systemctl is-active apache2 && echo "Apache running / Apache actif" || echo "Apache stopped / Apache arrêté")
  MDB_STATUS=$(systemctl is-active mariadb && echo "MariaDB running / MariaDB actif" || echo "MariaDB stopped / MariaDB arrêté")
  GLPI_STATUS=$( [ -d "$GLPI_DIR" ] && echo "GLPI directory exists / Répertoire GLPI : OK" || echo "GLPI missing / Répertoire GLPI manquant" )
  whiptail --title "Test Results / Résultats" --msgbox "$APACHE_STATUS\n$MDB_STATUS\n$GLPI_STATUS" 12 60
fi
