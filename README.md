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
- Configuration d’un **VirtualHost HTTPS** / **HTTPS VirtualHost** configuration
- Génération automatique d’un **certificat SSL** via **Certbot (Let's Encrypt)** / Automatic **SSL certificate** generation via **Certbot**
- Création d’une **base de données GLPI** / Creation of a **GLPI database**
- Configuration automatique des **permissions** / Automatic **permissions** configuration
- Interface d’installation prête à l’emploi à la fin du script / Ready-to-use installation interface at the end of the script

---

## 🧩 Prérequis / Prerequisites

Avant de lancer le script / Before running the script :

- Un système **Debian 12 / Ubuntu 22.04 ou supérieur** / **A Debian 12 / Ubuntu 22.04 or higher system**
- Accès **root** ou via `sudo` / **root** access or `sudo` privileges
- Un **nom de domaine** pointant vers le serveur ou l'adress IP du serveur/ A domain name pointing to the server or the IP address of the server
- Ports **80 (HTTP)** et **443 (HTTPS)** ouverts / Open ports 80 (HTTP) and 443 (HTTPS)
- Connexion Internet active / Active internet connection

---

## ⚙️ Installation / Installation

1. **Cloner le dépôt / Clone the repository :**
```bash
git clone https://github.com/memton80/glpi-auto.git
```
```bash
cd glpi-auto
```
Donner les droits d’exécution / Grant execution permissions :
```bash
chmod +x install-glpi-https.sh
```
Lancer le script / Run the script :
 ```bash
sudo bash ./install-glpi-https.sh
```
ou / or
 ```bash
bash ./install-glpi-https.sh
```

Pendant l’installation, le script vous demandera / During installation, the script will prompt you for :

- Le nom de domaine (ex : glpi.exemple.fr) ou l'adress IP / The domain name (e.g., glpi.example.com) or IP address
- Le mot de passe que vous voulez définir pour le compte glpi et MariaDB / The password you want to set for the GLPI account and MariaDB

### 🌐 Accès à l’interface GLPI / Accessing the GLPI Interface
Une fois le script terminé, accédez à votre interface GLPI via / Once the script completes, access your GLPI interface via :

`https://votre-domaine/ ou https://X.X.X.X/`

`https://your-domain/ or https://X.X.X.X/`

> [!NOTE]
> Identifiants par défaut / Default credentials :  **glpi**
>
>  Mot de passe / Password : **glpi**

> [!WARNING]
>Pensez à les changer après la première connexion 🔒 / Remember to change these after your first login 🔒

> [!TIP]
> Si vous avez oublié le mot de passe défini pour l'utilisateur GLPI ou l'adresse IP/domaine qui a été fini, le script l'affiche à la fin de l'installation / If you have forgotten the password set for the GLPI user or the IP/domain address that has been finished, the script displays it at the end of the installation



## 🛠️ Désinstallation / Uninstallation
Pour supprimer GLPI et ses dépendances / To remove GLPI and its dependencies :
 ```bash
sudo apt remove --purge apache2 mariadb-server php* -y
sudo rm -rf /var/www/html/glpi /etc/apache2/sites-available/glpi.conf
sudo systemctl restart apache2
```

> [!TIP]
>Le script est prévu pour une utilisation sur un serveur propre.
>Si vous avez déjà un site sur le port 443, pensez à créer un VirtualHost distinct ou à modifier le port HTTPS avant l’exécution.
>This script is designed for a clean server environment.
>If you already have a site running on port 443, consider creating a separate VirtualHost or modifying the HTTPS port before execution.

> [!NOTE]
>🧰 Objectif / Purpose
>Ce script simplifie le déploiement complet de GLPI — de l’installation à la configuration HTTPS, le tout en une seule commande.
>This script simplifies the complete deployment of GLPI — from installation to HTTPS configuration, all in a single command.

## 📖 Avertissement légal / Legal disclaimer 
> [!WARNING]
> L'utilisateur reconnaît et accepte que l'auteur du script ne peut être tenu pour responsable des éventuelles failles de sécurité, vulnérabilités ou dommages résultant de l'utilisation ou de
> l'installation du script. L'utilisation du script se fait sous la seule responsabilité de l'utilisateur, qui s'engage à en évaluer les risques et à prendre les mesures de sécurité appropriées.
>
> The user acknowledges and agrees that the script author shall not be liable for any security vulnerabilities, breaches, or damages arising from the use or installation of the script. The use of the script is at the user's sole risk, and the user is responsible for assessing the risks and implementing appropriate security measures.
