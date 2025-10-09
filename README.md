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

🌐 Accès à l’interface GLPI
Une fois le script terminé, accédez à votre interface GLPI via :

Copier le code
https://votre-domaine/

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

🪪 Auteur
Auteur : memton80
Projet : GLPI Auto Installer
Licence : GLP

💡 Astuce
Le script est prévu pour une utilisation serveur propre.
Si vous avez déjà un site sur le port 443, pensez à créer un VirtualHost distinct ou à modifier le port HTTPS avant l’exécution.

🧰 Ce script a été conçu pour simplifier le déploiement complet de GLPI — de l’installation à la configuration HTTPS, le tout en une seule commande.
