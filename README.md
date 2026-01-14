# Script d'installation automatique de GLPI avec HTTPS

## Automatic GLPI Installation Script with HTTPS

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-Bash-1f425f?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-GPL 3.0-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/GLPI-11.0.0+-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Debian%2012-yellow?style=for-the-badge">
  <img src="https://img.shields.io/badge/Security-Hardened-red?style=for-the-badge">
</p>

> Guide complet pour l'installation automatisée et sécurisée de GLPI sur Debian 12

> Complete guide for automated and secure GLPI installation on Debian 12

---

## Table des matières / Table of Contents

- [Fonctionnalités](#fonctionnalités--features)
- [Prérequis](#prérequis--prerequisites)
- [Installation](#installation)
- [Étapes d'installation](#étapes-dinstallation--installation-steps)
- [Accès à l'interface GLPI](#accès-à-linterface-glpi--accessing-the-glpi-interface)
- [Désinstallation](#désinstallation--uninstallation)
- [Dépannage](#dépannage--troubleshooting)
- [Mesures de sécurité](#mesures-de-sécurité-appliquées--applied-security-measures)
- [Documentation](#documentation)
- [Licence](#licence--license)

---

## Fonctionnalités / Features

### Installation automatisée / Automated Installation

Ce projet contient un script Bash (`install-glpi-https.sh`) permettant d'installer **GLPI** sur un serveur **Debian 12** de manière automatisée et **sécurisée**, avec **Apache**, **MariaDB**, **PHP 8.2**, et un **certificat SSL auto-signé**.

This project contains a Bash script (`install-glpi-https.sh`) to automatically and **securely** install **GLPI** on a Debian 12 server, including **Apache**, **MariaDB**, **PHP 8.2**, and a **self-signed SSL certificate**.

**Caractéristiques principales / Main features:**
- Installation automatique de GLPI (dernière version stable depuis GitHub)
- Détection et téléchargement automatique de la dernière version
- Barre de progression réaliste pour chaque étape

**Main features:**
- Automatic installation of GLPI (latest stable version from GitHub)
- Automatic detection and download of the latest version
- Real-time progress bars for each step

### Stack technique / Technical Stack

**Apache2** avec modules SSL et Rewrite / with SSL and Rewrite modules

**MariaDB** sécurisé / hardened

**PHP 8.2** avec toutes les extensions requises / with all required extensions:
- mysql, xml, mbstring, curl, gd, intl, ldap, imap
- zip, bz2, cli, apcu, bcmath, opcache, exif

Configuration optimisée pour la production / Production-optimized configuration

### Sécurité renforcée / Enhanced Security

**Sécurisation complète de MariaDB / Complete MariaDB hardening:**
- Mot de passe root obligatoire / Mandatory root password
- Suppression des utilisateurs anonymes / Anonymous users removed
- Suppression de la base de test / Test database removed
- Credentials sauvegardés dans `/root/.mysql_credentials` (chmod 600)

**Protection des répertoires sensibles / Sensitive directories protection:**
- Déplacement de `/files` et `/config` vers `/var/lib/glpi/`
- Protection par `.htaccess` contre les accès directs
- Permissions restrictives (750/770)

**Validation des entrées / Input validation:**
- Anti-injection SQL pour les noms de bases et utilisateurs
- Regex strict (alphanumériques et underscores uniquement)

**Pare-feu UFW optionnel / Optional UFW firewall:**
- Configuration automatique (ports 22, 80, 443)
- Politique par défaut : deny incoming

**Logs sécurisés / Secure logs:**
- Mots de passe masqués dans `/var/log/glpi-install.log`

### Interface multilingue / Multilingual Interface

- Français
- English
- Système de traduction propre et extensible / Clean and extensible translation system
- Tous les messages et dialogues traduits / All messages and dialogs translated

### Configuration SSL / SSL Configuration

- Certificat HTTPS auto-signé / Self-signed HTTPS certificate
- Durée personnalisable / Customizable validity period
- Support domaine ou IP / Domain or IP support

### Accès distant MariaDB / Remote MariaDB Access

- Avertissement de sécurité bilingue / Bilingual security warning
- Choix entre local (127.0.0.1) ou réseau (0.0.0.0)
- Instructions pour modification ultérieure / Instructions for later modification

### Tests de vérification / Verification Tests

- Vérification du statut Apache / Apache status check
- Vérification du statut MariaDB / MariaDB status check
- Vérification de l'installation GLPI / GLPI installation check

### Désinstallation automatique / Automatic Uninstallation

- Script de désinstallation complet généré automatiquement
- Suppression propre de tous les composants / Clean removal of all components
- Utilisation sécurisée des credentials MySQL / Secure use of MySQL credentials

---

## Prérequis / Prerequisites

> [!IMPORTANT]
> Avant de lancer le script, assurez-vous d'avoir les éléments suivants:
>
> Before running the script, ensure you have the following:

**Système / System:**
- Un système **Debian 12** (Bookworm) / A **Debian 12** (Bookworm) system
- Accès **root** ou via `sudo` / **root** access or `sudo` privileges
- Connexion Internet active / Active internet connection

**Ressources / Resources:**
- **2 Go de RAM minimum** / **Minimum 2 GB RAM**
- **500 Mo d'espace disque** / **500 MB disk space**

**Réseau / Network:**
- Un **nom de domaine** ou **adresse IP** / A **domain name** or **IP address**
- Ports **80 (HTTP)** et **443 (HTTPS)** disponibles / Available ports 80 and 443

> [!NOTE]
> **Pour les machines virtuelles / For virtual machines:**
> - Vérifiez la configuration réseau (bridge ou NAT)
> - Assurez-vous que les ports 80/443 sont accessibles
> - Configurez correctement les interfaces réseau

---

## Installation

### 1. Installer Git / Install Git

```bash
apt update && apt install git -y
```

### 2. Cloner le dépôt / Clone the repository

```bash
git clone https://github.com/memton80/glpi-auto.git
cd glpi-auto
```

### 3. Rendre le script exécutable / Make the script executable

```bash
chmod +x install-glpi-https.sh
```

### 4. Lancer l'installation / Run the installation

```bash
./install-glpi-https.sh
```

ou avec sudo / or with sudo:

```bash
sudo ./install-glpi-https.sh
```

---

## Étapes d'installation / Installation Steps

Le script vous guidera interactivement à travers les étapes suivantes:

The script will guide you interactively through the following steps:

1. **Choix de la langue** / **Language selection** (Français/English)
2. **Confirmation** de l'installation / Installation **confirmation**
3. **Installation des dépendances** / **Dependencies installation** (Apache, MariaDB, PHP 8.2)
4. **Configuration de la base de données** / **Database configuration**:
   - Nom de la base / Database name
   - Utilisateur MySQL / MySQL user
   - Mot de passe (auto ou manuel) / Password (auto or manual)
5. **Sécurisation de MariaDB** / **MariaDB hardening**:
   - Définition du mot de passe root / Root password setup
   - Nettoyage des utilisateurs par défaut / Default users cleanup
6. **Choix accès distant MariaDB** / **Remote MariaDB access choice**
7. **Téléchargement de GLPI** / **GLPI download** (dernière version / latest version)
8. **Configuration SSL** / **SSL configuration**:
   - Domaine ou IP / Domain or IP
   - Durée du certificat / Certificate validity
9. **Configuration pare-feu (optionnel)** / **Firewall setup (optional)**
10. **Tests de vérification (optionnel)** / **Verification tests (optional)**
11. **Génération du script de désinstallation** / **Uninstall script generation**

---

## Accès à l'interface GLPI / Accessing the GLPI Interface

Une fois le script terminé, accédez à votre interface GLPI via:

Once the script completes, access your GLPI interface via:

```
https://votre-domaine/
https://your-domain/

ou / or

https://X.X.X.X/
```

### Identifiants par défaut / Default credentials

**Utilisateur / User:** `glpi`

**Mot de passe / Password:** `glpi`

> [!CAUTION]
> **SÉCURITÉ CRITIQUE / CRITICAL SECURITY**
>
> Changez immédiatement ces identifiants après la première connexion !
>
> Change these credentials immediately after first login!

---

## Informations affichées en fin d'installation / Information Displayed at Installation End

Le script affichera / The script will display:

- URL d'accès / Access URL
- Adresse IP du serveur / Server IP address
- Nom de la base de données / Database name
- Utilisateur de la base / Database user
- Mot de passe de la base / Database password
- Identifiants GLPI par défaut / Default GLPI credentials

> [!TIP]
> Ces informations sont également sauvegardées dans:
>
> This information is also saved in:
> - `/var/log/glpi-install.log` (mots de passe masqués / passwords hidden)
> - `/root/.mysql_credentials` (credentials MySQL root)

---

## Désinstallation / Uninstallation

Pour supprimer GLPI et tous ses composants:

To remove GLPI and all its components:

```bash
./uninstall-glpi.sh
```

Le script supprimera automatiquement:

The script will automatically remove:

- Tous les fichiers GLPI (`/var/www/html/glpi`, `/var/lib/glpi`)
- Les configurations Apache (`glpi.conf`, `glpi-ssl.conf`)
- Les certificats SSL (`/etc/ssl/glpi`)
- La base de données et l'utilisateur MySQL
- Les sites Apache activés

---

## Fichiers sensibles / Sensitive Files

> [!WARNING]
> Ne partagez JAMAIS ces fichiers / NEVER share these files:
> - `/root/.mysql_credentials` (mot de passe root MySQL)
> - `/var/log/glpi-install.log` (log d'installation)

---

## Dépannage / Troubleshooting

### Erreur "Unable to locate package php8.2-xxx"

```bash
apt update
apt install software-properties-common -y
```

### Le site n'est pas accessible via HTTPS

```bash
# Vérifier Apache
systemctl status apache2

# Vérifier les certificats
ls -l /etc/ssl/glpi/

# Recharger Apache
systemctl reload apache2
```

### Erreur de connexion à la base de données

```bash
# Vérifier MariaDB
systemctl status mariadb

# Tester la connexion
mysql --defaults-file=/root/.mysql_credentials -e "SHOW DATABASES;"
```

### Le firewall bloque l'accès

```bash
# Vérifier UFW
ufw status

# Autoriser temporairement tout
ufw disable

# Réactiver avec règles
ufw enable
```

---

## Structure du projet / Project Structure

```
glpi-auto/
├── install-glpi-https.sh    # Script d'installation principal / Main install script
├── uninstall-glpi.sh        # Généré automatiquement / Auto-generated
├── README.md                # Documentation
├── SECURITY.md              # Politique de sécurité / Security policy
└── LICENSE                  # Licence GPL-3.0
```

---

## Mesures de sécurité appliquées / Applied Security Measures

| Mesure / Measure | Description |
|------------------|-------------|
| **MariaDB hardening** | Root password, no anonymous users, no test DB |
| **File permissions** | 750 for GLPI, 770 for data dirs, 600 for credentials |
| **Directory protection** | `/files`, `/config`, `/install` protected by .htaccess |
| **Input validation** | Regex validation for DB names and users |
| **Firewall (optional)** | UFW with strict rules (22, 80, 443 only) |
| **SSL/TLS** | Self-signed certificate with configurable validity |
| **Secure logging** | Passwords masked in logs |
| **Session security** | HTTP-only and secure cookies enabled |

---

## Documentation

### Liens utiles / Useful Links

- [Documentation officielle GLPI](https://glpi-install.readthedocs.io/en/latest/)
- [GLPI sur GitHub](https://github.com/glpi-project/glpi)
- [Politique de sécurité](https://github.com/memton80/glpi-auto/blob/main/SECURITY.md)
- [Signaler un bug / Report a bug](https://github.com/memton80/glpi-auto/issues)

---

## Roadmap / To-Do List

- [x] Prise en charge bilingue FR/EN / Bilingual FR/EN support
- [x] Script de désinstallation automatique / Automatic uninstall script
- [x] Sécurisation complète de MariaDB / Complete MariaDB hardening
- [x] Protection des répertoires sensibles / Sensitive directories protection
- [x] Support du pare-feu UFW / UFW firewall support
- [x] Barres de progression réalistes / Real-time progress bars
- [x] Validation des entrées / Input validation
- [x] Gestion sécurisée des credentials / Secure credentials management
- [ ] Support multi-langue (ES, DE, IT) / Multi-language support
- [ ] Support de Debian 13 / Debian 13 support
- [ ] Support Ubuntu 24.04 LTS / Ubuntu 24.04 LTS support
- [ ] Mise à jour automatique de GLPI / Automatic GLPI updates
- [ ] Configuration SMTP / SMTP configuration
- [ ] Installation plugins GLPI / GLPI plugins installation
- [ ] Version Docker / Docker version
- [ ] Support Let's Encrypt / Let's Encrypt support

---

## Avertissement légal / Legal Disclaimer

> [!WARNING]
> **UTILISATION À VOS RISQUES / USE AT YOUR OWN RISK**
>
> L'utilisateur reconnaît et accepte que l'auteur du script ne peut être tenu pour responsable des éventuelles failles de sécurité, vulnérabilités ou dommages résultant de l'utilisation ou de l'installation du script. L'utilisation du script se fait sous la seule responsabilité de l'utilisateur, qui s'engage à en évaluer les risques et à prendre les mesures de sécurité appropriées.
>
> The user acknowledges and agrees that the script author shall not be liable for any security vulnerabilities, breaches, or damages arising from the use or installation of the script. The use of the script is at the user's sole risk, and the user is responsible for assessing the risks and implementing appropriate security measures.

> [!IMPORTANT]
> **RECOMMANDATIONS DE SÉCURITÉ / SECURITY RECOMMENDATIONS**
>
> - Effectuez des sauvegardes régulières / Perform regular backups
> - Changez tous les mots de passe par défaut / Change all default passwords
> - Utilisez des mots de passe forts et uniques / Use strong, unique passwords
> - Limitez l'accès réseau si possible / Restrict network access when possible
> - Maintenez GLPI et le système à jour / Keep GLPI and system updated
> - Ne partagez jamais vos credentials / Never share your credentials

---

## Licence / License

Ce projet est sous licence **GPL-3.0**

This project is licensed under **GPL-3.0**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

---

## Contribution / Contributing

Les contributions sont les bienvenues ! N'hésitez pas à:

Contributions are welcome! Feel free to:

1. Fork le projet / Fork the project
2. Créer une branche / Create a branch (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements / Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche / Push to the branch (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request / Open a Pull Request

---

**Auteur / Author:** memton80
