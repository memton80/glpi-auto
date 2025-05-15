#!/bin/bash

# 🎛️ Script d'installation interactive de GLPI pour Debian 12
# 🧑‍💻 Par Alexandre (avec l'aide de ChatGPT4o)

export PATH=$PATH:/usr/sbin:/sbin

# 🔐 Vérifie les droits root
if [[ $EUID -ne 0 ]]; then
  echo "🚫 Ce script doit être exécuté avec sudo ou en tant que root."
  exit 1
fi

if ! whiptail --title "Installation automatique de GLPI" --yesno "⚠️ Ce script effectue une installation *automatique* de GLPI avec les paramètres courants.\n\n✅ Idéal pour un test rapide ou un petit déploiement.\n\n🛠️ Pour une configuration avancée (LDAP, plugins, sécurité renforcée), il est recommandé de passer par l'installation manuelle via l'interface graphique après avoir accédé à https://<votre_domaine/ip local>/\n\nSouhaitez-vous continuer ?" 16 70; then
  echo "❌ Installation annulée par l'utilisateur."
  exit 1
fi

# 🌐 Test de connexion Internet (HTTP)
if ! wget -q --spider https://google.com; then
  whiptail --title "Erreur de connexion" --msgbox "❌ Aucune connexion Internet détectée.\nVérifiez votre réseau puis relancez le script." 10 60
  exit 1
fi

# 🗖️ Mise à jour & installation des dépendances
{
  echo 10; sleep 0.3
  apt update -y &> /dev/null
  echo 40; sleep 0.3
  apt install -y apache2 apache2-bin apache2-utils mariadb-server \
    php php-mysql php-xml php-mbstring php-curl php-gd php-intl php-ldap php-imap php-zip php-bz2 php-cli php-apcu \
    unzip wget tar \
    dialog whiptail curl openssl locales-all &> /dev/null
  echo 100; sleep 0.3
} | whiptail --gauge "📦 Mise à jour des paquets et installation des dépendances..." 6 60 0

# 📦 Infos base de données
DB_NAME=$(whiptail --title "Nom de la base de données" --inputbox "Entrez le nom de la base MySQL :" 10 60 "glpidb" 3>&1 1>&2 2>&3)
DB_USER=$(whiptail --title "Utilisateur MySQL" --inputbox "Entrez le nom d'utilisateur MySQL :" 10 60 "glpiuser" 3>&1 1>&2 2>&3)
if whiptail --title "Mot de passe MySQL" --yesno "🔐 Souhaitez-vous que le script génère un mot de passe fort automatiquement pour l'utilisateur $DB_USER ?" 10 60; then
  DB_PASS=$(openssl rand -base64 16)
  whiptail --title "Mot de passe généré" --msgbox "🔐 Mot de passe MySQL généré automatiquement :\n\n$DB_PASS\n\n💡 Pensez à le copier ou le noter." 12 60
else
  DB_PASS=$(whiptail --title "Mot de passe MySQL" --passwordbox "Entrez le mot de passe de l'utilisateur $DB_USER :" 10 60 3>&1 1>&2 2>&3)
fi

GLPI_DIR="/var/www/html/glpi"
GLPI_ARCHIVE="/tmp/glpi.tgz"

# 🔄 MySQL
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

whiptail --title "Sécurisation de MariaDB" --msgbox "Vous allez maintenant être invité à sécuriser votre installation MariaDB." 10 60
mysql_secure_installation

# 📥 GLPI
rm -f "$GLPI_ARCHIVE"
GLPI_URL=$(wget -qO- https://api.github.com/repos/glpi-project/glpi/releases/latest | grep browser_download_url | grep glpi.tgz | cut -d '"' -f 4)
if [[ -z "$GLPI_URL" ]]; then
  GLPI_URL="https://github.com/glpi-project/glpi/releases/download/10.0.18/glpi-10.0.18.tgz"
fi

{
  echo 10; sleep 0.3
  wget "$GLPI_URL" -O "$GLPI_ARCHIVE" &> /dev/null
  echo 50; sleep 0.3
  tar -xzf "$GLPI_ARCHIVE" -C /var/www/html/ &> /dev/null
  mv /var/www/html/glpi-* "$GLPI_DIR"
  echo 100; sleep 0.3
} | whiptail --gauge "📦 Téléchargement et extraction de GLPI..." 6 60 0

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
DOMAIN=$(whiptail --title "Nom de domaine ou IP" --inputbox "Entrez le nom de domaine ou l'adresse IP de votre serveur :" 10 60 3>&1 1>&2 2>&3)

if whiptail --title "HTTPS Auto-signé" --yesno "Voulez-vous créer un certificat HTTPS auto-signé pour $DOMAIN ?" 10 60; then
  SSL_DIR="/etc/ssl/glpi"
  mkdir -p "$SSL_DIR"
CERT_DAYS=$(whiptail --title "Durée du certificat HTTPS" --inputbox "Entrez la durée de validité du certificat auto-signé (en jours) :" 10 60 "365" 3>&1 1>&2 2>&3)

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
PHP_INI_FILE="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"
sed -i "s/^;*intl.default_locale\s*=.*/intl.default_locale = fr_FR/" "$PHP_INI_FILE"
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
if whiptail --title "Désinstallation" --yesno "Souhaitez-vous créer un script de désinstallation automatique ?" 10 60; then
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
  whiptail --msgbox "🧽 Script créé : ./uninstall-glpi.sh" 10 60
fi
