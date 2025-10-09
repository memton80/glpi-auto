# 🚀 Script d’installation automatique de GLPI avec HTTPS / Automatic GLPI Installation Script with HTTPS

Ce projet contient un script Bash (`install-glpi-https.sh`) permettant d’installer **GLPI** sur un serveur **Debian/Ubuntu** de manière automatisée, avec **Apache**, **MariaDB**, **PHP**, et un **certificat SSL (Let's Encrypt)**.  
This project contains a Bash script (`install-glpi-https.sh`) to automatically install **GLPI** on a Debian/Ubuntu server, including **Apache**, **MariaDB**, **PHP**, and an **SSL certificate (Let's Encrypt)**.

---

## 🧠 Fonctionnalités / Features

- Installation automatique de **GLPI** (version stable depuis le site officiel)  
  Automatic installation of **GLPI** (stable version from the official site)
- Installation et configuration de / Installation and configuration of :  
  - **Apache2**  
  - **MariaDB**  
  - **PHP et extensions nécessaires / PHP and required extensions**
- Configuration d’un **VirtualHost HTTPS** / HTTPS VirtualHost configuration
- Génération automatique d’un **certificat SSL** via **Certbot (Let's Encrypt)** / Automatic SSL certificate generation via Certbot
- Création d’une **base de données GLPI** / Creation of a GLPI database
- Configuration automatique des **permissions** / Automatic permissions configuration
- Interface d’installation prête à l’emploi à la fin du script / Ready-to-use installation interface at the end of the script

---

## 🧩 Prérequis / Prerequisites

Avant de lancer le script / Before running the script :

- Un système **Debian 12 / Ubuntu 22.04 ou supérieur** / A Debian 12 / Ubuntu 22.04 or higher system
- Accès **root** ou via `sudo` / Root access or sudo privileges
- Un **nom de domaine** pointant vers le serveur / A domain name pointing to the server
- Ports **80 (HTTP)** et **443 (HTTPS)** ouverts / Open ports 80 (HTTP) and 443 (HTTPS)
- Connexion Internet active / Active internet connection

---

## ⚙️ Installation / Installation

1. **Cloner le dépôt / Clone the repository :**

git clone https://github.com/memton80/glpi-auto.git
cd glpi-auto
Donner les droits d’exécution / Grant execution permissions :

bash
Copier le code
chmod +x install-glpi-https.sh
Lancer le script / Run the script :
 ```bash
sudo ./install-glpi-https.sh
```
Pendant l’installation, le script vous demandera / During installation, the script will prompt you for :

Le nom de domaine (ex : glpi.exemple.fr) oul'adress IP / The domain name (e.g., glpi.example.com) or IP address

Le mot de passe MariaDB root / The MariaDB root password

Le mot de passe de la base GLPI / The GLPI database password

🌐 Accès à l’interface GLPI / Accessing the GLPI Interface
Une fois le script terminé, accédez à votre interface GLPI via / Once the script completes, access your GLPI interface via :

`https://votre-domaine/ ou https://X.X.X.X/`

`https://your-domain/ or https://X.X.X.X/`

> [!NOTE]
> Identifiants par défaut / Default credentials :
>Utilisateur / Username : **glpi**
>
>  Mot de passe / Password : **glpi**

> [!WARNING]
>Pensez à les changer après la première connexion 🔒 / Remember to change these after your first login 🔒

🛠️ Désinstallation / Uninstallation
Pour supprimer GLPI et ses dépendances / To remove GLPI and its dependencies :
 ```bash
sudo apt remove --purge apache2 mariadb-server php* -y
sudo rm -rf /var/www/html/glpi /etc/apache2/sites-available/glpi.conf
sudo systemctl restart apache2
```
🪪 Auteur / Author
Auteur / Author : memton80

Projet / Project : GLPI Auto Installer

Licence / License : GPL

> [!TIP]
>💡 Astuce / Tip :
>Le script est prévu pour une utilisation sur un serveur propre.
>Si vous avez déjà un site sur le port 443, pensez à créer un VirtualHost distinct ou à modifier le port HTTPS avant l’exécution.
>This script is designed for a clean server environment.
>If you already have a site running on port 443, consider creating a separate VirtualHost or modifying the HTTPS port before execution.

> [!NOTE]
>🧰 Objectif / Purpose
>Ce script simplifie le déploiement complet de GLPI — de l’installation à la configuration HTTPS, le tout en une seule commande.
>This script simplifies the complete deployment of GLPI — from installation to HTTPS configuration, all in a single command.
