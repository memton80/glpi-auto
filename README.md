# 🚀 Script d’installation automatique de GLPI avec HTTPS

Ce projet contient un script Bash (`install-glpi-https.sh`) permettant d’installer **GLPI** sur un serveur **Debian/Ubuntu** de manière automatisée, avec **Apache**, **MariaDB**, **PHP**, et un **certificat SSL (Let's Encrypt)**.

---

## 🧠 Fonctionnalités

- Installation automatique de **GLPI** (version stable depuis le site officiel)
- Installation et configuration de :
  - **Apache2**
  - **MariaDB**
  - **PHP et extensions nécessaires**
- Configuration d’un **VirtualHost HTTPS**
- Génération automatique d’un **certificat SSL** via **Certbot (Let's Encrypt)**
- Création d’une **base de données GLPI**
- Configuration automatique des **permissions**
- Interface d’installation prête à l’emploi à la fin du script

---

## 🧩 Prérequis

Avant de lancer le script :

- Un système **Debian 12 / Ubuntu 22.04 ou supérieur**
- Accès **root** ou via `sudo`
- Un **nom de domaine** pointant vers le serveur
- Ports **80 (HTTP)** et **443 (HTTPS)** ouverts
- Connexion Internet active

---

## ⚙️ Installation

# 1. Cloner le dépôt

git clone https://github.com/memton80/glpi-auto.git
cd glpi-auto
# 2. Donner les droits d’exécution
chmod +x install-glpi-https.sh

# 3. Lancer le script
sudo ./install-glpi-https.sh
Pendant l’installation, le script vous demandera :

le nom de domaine (ex : glpi.exemple.fr)

le mot de passe MariaDB root

le mot de passe de la base GLPI

###🌐 Accès à l’interface GLPI
Une fois le script terminé, accédez à votre interface GLPI via :

https://votre-domaine/ ou https://X.X.X.X/

Les identifiants par défaut sont :
Utilisateur : glpi
Mot de passe : glpi

Pensez à les changer après la première connexion 🔒

## 🛠️ Désinstallation
Pour supprimer GLPI et ses dépendances :

Copier le code
sudo apt remove --purge apache2 mariadb-server php* -y
sudo rm -rf /var/www/html/glpi /etc/apache2/sites-available/glpi.conf
sudo systemctl restart apache2

#🪪 Auteur
Auteur : memton80
Projet : GLPI Auto Installer
Licence : GLP

💡 Astuce
Le script est prévu pour une utilisation serveur propre.
Si vous avez déjà un site sur le port 443, pensez à créer un VirtualHost distinct ou à modifier le port HTTPS avant l’exécution.

🧰 Ce script a été conçu pour simplifier le déploiement complet de GLPI — de l’installation à la configuration HTTPS, le tout en une seule commande.


#🚀 Automatic GLPI Installation Script with HTTPS
This project contains a Bash script (install-glpi-https.sh) to automatically install GLPI on a Debian/Ubuntu server, including Apache, MariaDB, PHP, and an SSL certificate (Let's Encrypt).

##🧠 Features

Automatic installation of GLPI (stable version from the official site)
Installation and configuration of:

Apache2
MariaDB
PHP and required extensions


HTTPS VirtualHost configuration

Automatic SSL certificate generation via Certbot (Let's Encrypt)

Creation of a GLPI database
Automatic permissions configuration
Ready-to-use installation interface at the end of the script


##🧩 Prerequisites
Before running the script:

A Debian 12 / Ubuntu 22.04 or higher system
Root access or sudo privileges
A domain name pointing to the server
Open ports 80 (HTTP) and 443 (HTTPS)
Active internet connection


##⚙️ Installation
1. Clone the repository
git clone https://github.com/memton80/glpi-auto.git
cd glpi-auto
2. Grant execution permissions
chmod +x install-glpi-https.sh
3. Run the script
sudo ./install-glpi-https.sh
During installation, the script will prompt you for:

The domain name (e.g., glpi.example.com)
The MariaDB root password
The GLPI database password


###🌐 Accessing the GLPI Interface
Once the script completes, access your GLPI interface via:
https://your-domain/ or https://X.X.X.X/
Default credentials are:

Username: glpi
Password: glpi

Remember to change these after your first login! 🔒

##🛠️ Uninstallation
To remove GLPI and its dependencies:
sudo apt remove --purge apache2 mariadb-server php* -y
sudo rm -rf /var/www/html/glpi /etc/apache2/sites-available/glpi.conf
sudo systemctl restart apache2

#🪪 Author

Author: memton80
Project: GLPI Auto Installer
License: GPL


💡 Tip
This script is designed for a clean server environment. If you already have a site running on port 443, consider creating a separate VirtualHost or modifying the HTTPS port before execution.

🧰 Purpose
This script simplifies the complete deployment of GLPI—from installation to HTTPS configuration—all in a single command.
