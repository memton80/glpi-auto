#!/bin/bash
# 🎛️ Script d'installation interactive de GLPI pour Debian 12
# 🧑‍💻 Par Alexandre
export PATH=$PATH:/usr/sbin:/sbin

# Menu de sélection de langue
LANG_CHOICE=$(whiptail --title "Language Selection" --menu "Choose your language:" 15 60 2 \
  "1" "Français" \
  "2" "English" \
  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo "❌ Installation annulée par l'utilisateur."
  exit 1
fi

if [ "$LANG_CHOICE" = "1" ]; then
  LANG="fr"
else
  LANG="en"
fi

# Définir les messages en fonction de la langue choisie
if [ "$LANG" = "fr" ]; then
  MSG_ROOT_CHECK="🚫 Ce script doit être exécuté avec sudo ou en tant que root."
  MSG_INSTALL_CANCEL="❌ Installation annulée par l'utilisateur."
  MSG_UPDATE_DEPS="📦 Mise à jour des paquets et installation des dépendances..."
  MSG_DB_NAME="Entrez le nom de la base MySQL :"
  MSG_DB_USER="Entrez le nom d'utilisateur MySQL :"
  MSG_DB_PASS_GEN="🔐 Souhaitez-vous que le script génère un mot de passe fort automatiquement pour l'utilisateur"
  MSG_DB_PASS_GEN_TITLE="Mot de passe MySQL"
  MSG_DB_PASS_GEN_MSG="🔐 Mot de passe MySQL généré automatiquement :\n\n"
  MSG_DB_PASS_PROMPT="Entrez le mot de passe de l'utilisateur"
  MSG_SECURE_MDB="Vous allez maintenant être invité à sécuriser votre installation MariaDB."
  MSG_DOWNLOAD_GLPI="📦 Téléchargement et extraction de GLPI..."
  MSG_APACHE_CONFIG="🌍 Configuration d'Apache..."
  MSG_FINISHED="✅ GLPI est installé avec succès !\n\n➡️ Adresse : https://\$DOMAIN/\n📡 IP locale : \$IP\n👤 Utilisateur par défaut : glpi / glpi\n\n                     🐾"
  MSG_UNINSTALL_PROMPT="Souhaitez-vous créer un script de désinstallation automatique ?"
  MSG_UNINSTALL_SCRIPT="🧽 Script créé : ./uninstall-glpi.sh"
  MSG_CONTINUE_INSTALL="⚠️ Ce script effectue une installation *automatique* de GLPI avec les paramètres courants.\n\n✅ Idéal pour un test rapide ou un petit déploiement.\n\n🛠️ Pour une configuration avancée (LDAP, plugins, sécurité renforcée), il est recommandé de passer par l'installation manuelle via l'interface graphique après avoir accédé à https://<votre_domaine/ip local>/\n\nSouhaitez-vous continuer ?"
  MSG_GEN_PASS_PROMPT="🔐 Souhaitez-vous que le script génère un mot de passe fort automatiquement pour l'utilisateur"
  MSG_SSL_CERT_PROMPT="Voulez-vous créer un certificat HTTPS auto-signé pour"
  MSG_TEST_MENU="Souhaitez-vous exécuter quelques tests pour vérifier l'installation ?"
  MSG_TEST_RESULTS="Tests effectués avec succès !"
else
  MSG_ROOT_CHECK="🚫 This script must be run with sudo or as root."
  MSG_INSTALL_CANCEL="❌ Installation cancelled by the user."
  MSG_UPDATE_DEPS="📦 Updating packages and installing dependencies..."
  MSG_DB_NAME="Enter the MySQL database name:"
  MSG_DB_USER="Enter the MySQL username:"
  MSG_DB_PASS_GEN="🔐 Do you want the script to automatically generate a strong password for the user"
  MSG_DB_PASS_GEN_TITLE="MySQL Password"
  MSG_DB_PASS_GEN_MSG="🔐 Automatically generated MySQL password:\n\n"
  MSG_DB_PASS_PROMPT="Enter the password for the user"
  MSG_SECURE_MDB="You will now be prompted to secure your MariaDB installation."
  MSG_DOWNLOAD_GLPI="📦 Downloading and extracting GLPI..."
  MSG_APACHE_CONFIG="🌍 Configuring Apache..."
  MSG_FINISHED="✅ GLPI is successfully installed!\n\n➡️ Address: https://\$DOMAIN/\n📡 Local IP: \$IP\n👤 Default user: glpi / glpi\n\n                     🐾"
  MSG_UNINSTALL_PROMPT="Do you want to create an automatic uninstall script?"
  MSG_UNINSTALL_SCRIPT="🧽 Script created: ./uninstall-glpi.sh"
  MSG_CONTINUE_INSTALL="⚠️ This script performs an *automatic* installation of GLPI with the default settings.\n\n✅ Ideal for a quick test or small deployment.\n\n🛠️ For advanced configuration (LDAP, plugins, enhanced security), it is recommended to proceed with manual installation via the graphical interface after accessing https://<your_domain/local_ip>/\n\nDo you want to continue?"
  MSG_GEN_PASS_PROMPT="🔐 Do you want the script to automatically generate a strong password for the user"
  MSG_SSL_CERT_PROMPT="Do you want to create a self-signed HTTPS certificate for"
  MSG_TEST_MENU="Do you want to run some tests to verify the installation?"
  MSG_TEST_RESULTS="Tests completed successfully!"
fi

# Vérifie les droits root
if [[ $EUID -ne 0 ]]; then
  echo "$MSG_ROOT_CHECK"
  exit 1
fi

if ! whiptail --title "GLPI Installation" --yesno "$MSG_CONTINUE_INSTALL" 16 70; then
  echo "$MSG_INSTALL_CANCEL"
  exit 1
fi

# 🌐 Test de connexion Internet (HTTP)
if ! wget -q --spider https://google.com; then
  if [ "$LANG" = "fr" ]; then
    whiptail --title "Erreur de connexion" --msgbox "❌ Aucune connexion Internet détectée.\nVérifiez votre réseau puis relancez le script." 10 60
  else
    whiptail --title "Connection Error" --msgbox "❌ No Internet connection detected.\nCheck your network and try again." 10 60
  fi
  exit 1
fi

# 🗖️ Mise à jour & installation des dépendances
{
  echo 10; sleep 0.3
  apt update -y &> /dev/null
  echo 40; sleep 0.3
  apt install -y apache2 apache2-bin apache2-utils mariadb-server \
    php8.2 php8.2-mysql php8.2-xml php8.2-mbstring php8.2-curl php8.2-gd php8.2-intl php8.2-ldap php8.2-imap php8.2-zip php8.2-bz2 php8.2-cli php8.2-apcu \
    unzip wget tar \
    dialog whiptail curl openssl locales-all &> /dev/null
  echo 100; sleep 0.3
} | whiptail --gauge "$MSG_UPDATE_DEPS" 6 60 0

# 📦 Infos base de données
DB_NAME=$(whiptail --title "Database Name" --inputbox "$MSG_DB_NAME" 10 60 "glpidb" 3>&1 1>&2 2>&3)
DB_USER=$(whiptail --title "MySQL User" --inputbox "$MSG_DB_USER" 10 60 "glpiuser" 3>&1 1>&2 2>&3)

if whiptail --title "$MSG_DB_PASS_GEN_TITLE" --yesno "$MSG_GEN_PASS_PROMPT $DB_USER ?" 10 60; then
  DB_PASS=$(openssl rand -base64 16 | tr -d '=+/[:space:]' | cut -c1-16)
  whiptail --title "$MSG_DB_PASS_GEN_TITLE" --msgbox "$MSG_DB_PASS_GEN_MSG\n\n$DB_PASS\n\n💡 Pensez à le copier ou le noter." 12 60
else
  DB_PASS=$(whiptail --title "$MSG_DB_PASS_GEN_TITLE" --passwordbox "$MSG_DB_PASS_PROMPT $DB_USER :" 10 60 3>&1 1>&2 2>&3)
fi

GLPI_DIR="/var/www/html/glpi"
GLPI_ARCHIVE="/tmp/glpi.tgz"

# 🔄 MySQL
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

whiptail --title "MariaDB Securing" --msgbox "$MSG_SECURE_MDB" 10 60
mysql_secure_installation

# 📥 GLPI
rm -f "$GLPI_ARCHIVE"
GLPI_URL=$(wget -qO- https://api.github.com/repos/glpi-project/glpi/releases/latest | grep browser_download_url | grep glpi.tgz | cut -d '"' -f 4)
if [[ -z "$GLPI_URL" ]]; then
  GLPI_URL="https://github.com/glpi-project/glpi/releases/download/11.0.0/glpi-11.0.0.tgz"
fi

{
  echo 10; sleep 0.3
  wget "$GLPI_URL" -O "$GLPI_ARCHIVE" &> /dev/null
  echo 50; sleep 0.3
  tar -xzf "$GLPI_ARCHIVE" -C /var/www/html/ &> /dev/null
  mv /var/www/html/glpi-* "$GLPI_DIR"
  echo 100; sleep 0.3
} | whiptail --gauge "$MSG_DOWNLOAD_GLPI" 6 60 0

# 📂 Permissions
chown -R www-data:www-data "$GLPI_DIR"
chmod -R 755 "$GLPI_DIR"

# ⚙️ Apache - HTTP
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

# 🔐 Apache - HTTPS auto-signé
DOMAIN=$(whiptail --title "Domain or IP" --inputbox "Entrez le nom de domaine ou l'adresse IP de votre serveur :" 10 60 3>&1 1>&2 2>&3)
if whiptail --title "Self-signed HTTPS" --yesno "$MSG_SSL_CERT_PROMPT $DOMAIN ?" 10 60; then
  SSL_DIR="/etc/ssl/glpi"
  mkdir -p "$SSL_DIR"
  CERT_DAYS=$(whiptail --title "HTTPS Certificate Duration" --inputbox "Entrez la durée de validité du certificat auto-signé (en jours) :" 10 60 "365" 3>&1 1>&2 2>&3)
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
  /usr/sbin/a2enmod ssl
  /usr/sbin/a2ensite glpi-ssl.conf
fi

# 🔁 Activation Apache
/usr/sbin/a2ensite glpi.conf
systemctl reload apache2

# 🌍 PHP config FR + secure
PHP_INI_FILE="/etc/php/8.2/apache2/php.ini"
if [ "$LANG" = "fr" ]; then
  sed -i "s/^;*intl.default_locale\s*=.*/intl.default_locale = fr_FR/" "$PHP_INI_FILE"
else
  sed -i "s/^;*intl.default_locale\s*=.*/intl.default_locale = en_US/" "$PHP_INI_FILE"
fi
sed -i "s/^;*session.cookie_httponly\s*=.*/session.cookie_httponly = On/" "$PHP_INI_FILE"
sed -i "s/^;*session.cookie_secure\s*=.*/session.cookie_secure = On/" "$PHP_INI_FILE"
systemctl reload apache2

# 🔁 Activation du module rewrite et création du .htaccess
/usr/sbin/a2enmod rewrite
cat << 'EOF' > "$GLPI_DIR/public/.htaccess"
<IfModule mod_rewrite.c>
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>
EOF
systemctl restart apache2
echo "✅ Module rewrite activé et .htaccess généré 🛠️"

# ✅ Fin
IP=$(hostname -I | awk '{print $1}')
whiptail --title "Installation terminée 🚀" --msgbox "✅ GLPI est installé avec succès !\n\n➡️ Adresse : https://$DOMAIN/\n📡 IP locale : $IP\n👤 Utilisateur par défaut : glpi / glpi\n\n                     🐾" 14 60

# 🗑️ Désinstallateur
if whiptail --title "Uninstall" --yesno "$MSG_UNINSTALL_PROMPT" 10 60; then
  cat << REMOVE > uninstall-glpi.sh
#!/bin/bash
rm -rf "$GLPI_DIR" "$GLPI_ARCHIVE"
rm /etc/apache2/sites-available/glpi.conf /etc/apache2/sites-available/glpi-ssl.conf
/usr/sbin/a2dissite glpi.conf
/usr/sbin/a2dissite glpi-ssl.conf
systemctl reload apache2
mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
echo "✅ GLPI et ses composants ont été supprimés."
REMOVE
  chmod +x uninstall-glpi.sh
  whiptail --msgbox "$MSG_UNINSTALL_SCRIPT" 10 60
fi

# Menu de test
if whiptail --title "Test Menu" --yesno "$MSG_TEST_MENU" 10 60; then
  # Vérifier que Apache est en cours d'exécution
  if systemctl is-active --quiet apache2; then
    if [ "$LANG" = "fr" ]; then
      APACHE_STATUS="Apache est en cours d'exécution."
    else
      APACHE_STATUS="Apache is running."
    fi
  else
    if [ "$LANG" = "fr" ]; then
      APACHE_STATUS="Apache n'est pas en cours d'exécution."
    else
      APACHE_STATUS="Apache is not running."
    fi
  fi

  # Vérifier que MariaDB est en cours d'exécution
  if systemctl is-active --quiet mariadb; then
    if [ "$LANG" = "fr" ]; then
      MDB_STATUS="MariaDB est en cours d'exécution."
    else
      MDB_STATUS="MariaDB is running."
    fi
  else
    if [ "$LANG" = "fr" ]; then
      MDB_STATUS="MariaDB n'est pas en cours d'exécution."
    else
      MDB_STATUS="MariaDB is not running."
    fi
  fi

  # Vérifier que le répertoire GLPI existe
  if [ -d "$GLPI_DIR" ]; then
    if [ "$LANG" = "fr" ]; then
      GLPI_DIR_STATUS="Le répertoire GLPI existe."
    else
      GLPI_DIR_STATUS="GLPI directory exists."
    fi
  else
    if [ "$LANG" = "fr" ]; then
      GLPI_DIR_STATUS="Le répertoire GLPI n'existe pas."
    else
      GLPI_DIR_STATUS="GLPI directory does not exist."
    fi
  fi

  # Afficher les résultats des tests
  whiptail --title "Test Results" --msgbox "$APACHE_STATUS\n$MDB_STATUS\n$GLPI_DIR_STATUS" 10 60
fi
