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
- Interface console dédiée, sans dépendance à `whiptail` ou `dialog`
- Installation automatique de GLPI (dernière version stable depuis GitHub)
- Détection et téléchargement automatique de la dernière version
- Barre de progression réelle, alimentée par apt et wget

**Main features:**
- Custom console interface, no `whiptail` or `dialog` dependency
- Automatic installation of GLPI (latest stable version from GitHub)
- Automatic detection and download of the latest version
- Real progress bars, driven by actual apt and wget output

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

### Interface console / Console Interface

L'interface est écrite entièrement en Bash (aucun `whiptail`, aucun `dialog`).

The interface is written entirely in Bash (no `whiptail`, no `dialog`).

- **Panneau Machine** en haut à droite : nom d'hôte, adresse IP, système, état du
  pare-feu et disponibilité des ports 80 et 443, actualisables avec la touche `r`
- **Panneau Configuration** : tous les paramètres regroupés dans des sections
  dépliables (base de données, sécurité, web/HTTPS, options)
- **Bouton INSTALLER** en bas, actif une fois la configuration validée
- **Écrans d'installation** : Tux animé au-dessus d'une barre de progression, la
  sortie des commandes étant redirigée vers le journal plutôt qu'à l'écran
- Interface en français uniquement / French interface only

### Configuration SSL / SSL Configuration

- Certificat HTTPS auto-signé / Self-signed HTTPS certificate
- Durée personnalisable / Customizable validity period
- Support domaine ou IP / Domain or IP support

### Accès distant MariaDB / Remote MariaDB Access

- Option désactivée par défaut, aide de sécurité affichée dans le formulaire
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

**Terminal:**
- Une **console interactive** d'au moins **74x20** caractères / An **interactive
  terminal** of at least **74x20** characters
- Un terminal compatible **UTF-8** pour l'affichage des cadres (repli automatique
  en ASCII sinon) / A **UTF-8** capable terminal for the box drawing (automatic
  ASCII fallback otherwise)

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

Toute la configuration se fait sur un seul écran, avant que la moindre
modification ne soit appliquée au système.

Everything is configured on a single screen, before any change is applied to
the system.

### 1. Écran de configuration / Configuration screen

Naviguez avec les flèches, `Entrée` pour modifier un champ, `Espace` pour basculer
un `oui`/`non`, `Gauche`/`Droite` pour plier ou déplier une section, `r` pour
actualiser les informations machine et `q` pour quitter.

| Section | Paramètres / Settings |
|---|---|
| Base de données | nom de la base, utilisateur MySQL, mot de passe (généré ou saisi) |
| Sécurité | mot de passe root MariaDB, accès distant MariaDB, pare-feu UFW |
| Web et HTTPS | domaine ou IP, certificat auto-signé, durée du certificat |
| Options | script de désinstallation, tests de vérification |

Les valeurs sont validées à la saisie (anti-injection SQL, longueur des mots de
passe, double saisie de confirmation) puis une nouvelle fois avant l'installation.

### 2. Téléchargement / Download

Écran avec Tux qui avance au rythme de la progression réelle:
mise à jour des listes de paquets, Apache et MariaDB, PHP et ses extensions,
utilitaires, puis l'archive GLPI (dernière version détectée sur GitHub).

### 3. Installation

Écran avec Tux animé et la mention **INSTALLATION EN COURS**:
extraction de l'archive, création de la base et de l'utilisateur, sécurisation de
MariaDB, écoute réseau, permissions et répertoires protégés, vhosts Apache et
certificat, configuration PHP, `.htaccess`, pare-feu UFW, script de
désinstallation.

### 4. Récapitulatif / Summary

URL d'accès, identifiants de la base, emplacement des credentials root, résultat
des tests de vérification et chemin du journal complet.

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

- [x] Interface console maison, sans whiptail / Custom console interface, no whiptail
- [x] Script de désinstallation automatique / Automatic uninstall script
- [x] Sécurisation complète de MariaDB / Complete MariaDB hardening
- [x] Protection des répertoires sensibles / Sensitive directories protection
- [x] Support du pare-feu UFW / UFW firewall support
- [x] Barres de progression réelles / Real progress bars
- [x] Validation des entrées / Input validation
- [x] Gestion sécurisée des credentials / Secure credentials management
- [ ] Support multi-langue / Multi-language support (interface actuellement en français)
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
