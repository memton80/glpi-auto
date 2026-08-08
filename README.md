# Script d'installation automatique de GLPI avec HTTPS

## Automatic GLPI Installation Script with HTTPS

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-Bash-1f425f?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-GPL 3.0-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/GLPI-11.0.0+-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Debian%2012%20%7C%2013-yellow?style=for-the-badge">
  <img src="https://img.shields.io/badge/Security-Hardened-red?style=for-the-badge">
</p>

> Guide complet pour l'installation automatisée et sécurisée de GLPI sur Debian 12 et Debian 13

> Complete guide for automated and secure GLPI installation on Debian 12 and Debian 13

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

Ce projet contient un script Bash (`install-glpi-https.sh`) permettant d'installer **GLPI** sur un serveur **Debian 12 ou Debian 13** de manière automatisée et **sécurisée**, avec **Apache**, **MariaDB**, **PHP**, et un **certificat SSL auto-signé**. Le script détecte la version de la distribution et adapte la liste des paquets qu'il demande à `apt`.

This project contains a Bash script (`install-glpi-https.sh`) to automatically and **securely** install **GLPI** on a Debian 12 or Debian 13 server, including **Apache**, **MariaDB**, **PHP**, and a **self-signed SSL certificate**. The script detects the distribution release and adapts the package list it requests from `apt`.

**Caractéristiques principales / Main features:**
- Interface console dédiée, sans dépendance à `whiptail` ou `dialog`
- Installation automatique de GLPI (dernière version stable depuis GitHub)
- Détection et téléchargement automatique de la dernière version
- Barre de progression réelle, alimentée par apt et wget
- En cas d'échec (coupure réseau, paquet manquant...), Tux s'effondre à l'écran
  et la fenêtre d'erreur indique l'étape fautive et les dernières lignes du log

**Main features:**
- Custom console interface, no `whiptail` or `dialog` dependency
- Automatic installation of GLPI (latest stable version from GitHub)
- Automatic detection and download of the latest version
- Real progress bars, driven by actual apt and wget output
- On failure (network drop, missing package...), Tux collapses on screen and the
  error window reports the failing step and the last lines of the log

### Stack technique / Technical Stack

**Apache2** avec modules SSL et Rewrite / with SSL and Rewrite modules

**MariaDB** sécurisé / hardened

**PHP** (8.2 sur Debian 12, 8.4 sur Debian 13) avec toutes les extensions
requises / (8.2 on Debian 12, 8.4 on Debian 13) with all required extensions:
- mysql, xml, mbstring, curl, gd, intl, zip, bz2, cli, bcmath, opcache
- optionnelles, posées si la distribution les fournit / optional, installed when
  the distribution provides them: ldap, apcu, exif, sodium, imap

> `php-imap` n'existe plus sur Debian 13 : PHP 8.4 ne fournit plus l'extension
> IMAP et Debian a retiré le paquet. GLPI 11 ne l'utilise plus, le script la
> saute donc automatiquement sur cette version.
>
> `php-imap` no longer exists on Debian 13: PHP 8.4 dropped the IMAP extension
> and Debian removed the package. GLPI 11 no longer uses it, so the script skips
> it automatically on that release.

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

- **Panneau Machine** en haut à droite : nom d'hôte, adresse IP, système,
  processeur, mémoire, espace disque, état du pare-feu et disponibilité des ports
  80 et 443, actualisables avec la touche `r`
- **Contrôle du matériel** au démarrage : un avertissement détaillé s'affiche si
  le processeur, la mémoire ou l'espace disque sont sous-dimensionnés, et le
  rappel est repris dans la fenêtre de confirmation avant l'installation
- **Panneau Configuration** : tous les paramètres regroupés dans des sections
  dépliables (base de données, sécurité, web/HTTPS, options)
- **Bouton INSTALLER** en bas, actif une fois la configuration validée
- **Écrans d'installation** : Tux animé au-dessus d'une barre de progression, la
  sortie des commandes étant redirigée vers le journal plutôt qu'à l'écran
- **Thème clair ou sombre** détecté automatiquement à partir de la couleur de fond
  du terminal, avec bascule manuelle par la touche `t` ou la variable
  d'environnement `GLPI_THEME=light|dark`
- **Français ou anglais**, choisi sur un écran au lancement du script, ou imposé
  par la variable d'environnement `GLPI_LANG=fr|en` / **French or English**,
  selected on a startup screen or forced with `GLPI_LANG=fr|en`

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

- Script `uninstall-glpi.sh` généré automatiquement, avec **sa propre interface
  console** (mêmes panneaux, même Tux, même barre de progression que
  l'installateur)
- Chaque élément à supprimer est cochable : fichiers, base, configuration
  Apache, tâches cron, paquets Apache / PHP / MariaDB, règles UFW
- **Libère les ports 80 et 443** pour qu'une réinstallation reparte sur une
  machine propre
- Récapitulatif final vérifié : ce qui a réellement disparu, ce qui reste
- Mode texte pour les scripts : `-y`, `--all`, `--keep-packages`

- Auto-generated `uninstall-glpi.sh` with **its own console interface** (same
  panels, same Tux, same progress bar as the installer)
- Every item is a checkbox: files, database, Apache configuration, cron jobs,
  Apache / PHP / MariaDB packages, UFW rules
- **Frees ports 80 and 443** so a reinstall starts from a clean machine
- Verified final report: what is really gone, what is left
- Text mode for scripting: `-y`, `--all`, `--keep-packages`

---

## Prérequis / Prerequisites

> [!IMPORTANT]
> Avant de lancer le script, assurez-vous d'avoir les éléments suivants:
>
> Before running the script, ensure you have the following:

**Système / System:**
- Un système **Debian 12** (Bookworm) ou **Debian 13** (Trixie) /
  A **Debian 12** (Bookworm) or **Debian 13** (Trixie) system
- Accès **root** ou via `sudo` / **root** access or `sudo` privileges
- Connexion Internet active / Active internet connection

**Ressources / Resources:**
- **2 Go de RAM** recommandés, 1 Go strict minimum / **2 GB RAM** recommended,
  1 GB absolute minimum
- **5 Go d'espace disque libre** sur `/var` recommandés, 2 Go strict minimum /
  **5 GB free disk space** on `/var` recommended, 2 GB absolute minimum
- **2 cœurs** recommandés / **2 CPU cores** recommended

Le script mesure ces trois valeurs au démarrage et affiche un avertissement si
elles sont insuffisantes. L'installation reste possible dans tous les cas.

The script measures these three values at startup and warns if they are too low.
Installation remains possible in every case.

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

### 1. Choix de la langue / Language selection

Le script s'ouvre sur un écran bilingue proposant **Français** et **English**.
Toute la suite (formulaire, avertissements, écrans d'installation, récapitulatif
et script de désinstallation généré) utilise la langue retenue. `GLPI_LANG=fr` ou
`GLPI_LANG=en` permet de sauter cet écran.

The script opens on a bilingual screen offering **Français** and **English**. The
whole session then uses the selected language. Set `GLPI_LANG=fr` or
`GLPI_LANG=en` to skip that screen.

### 2. Écran de configuration / Configuration screen

Naviguez avec les flèches, `Entrée` pour modifier un champ, `Espace` pour basculer
un `oui`/`non`, `Gauche`/`Droite` pour plier ou déplier une section, `r` pour
actualiser les informations machine, `t` pour basculer entre thème clair et
sombre, et `q` pour quitter.

| Section | Paramètres / Settings |
|---|---|
| Base de données | nom de la base, utilisateur MySQL, mot de passe (généré ou saisi) |
| Sécurité | mot de passe root MariaDB, accès distant MariaDB, pare-feu UFW |
| Web et HTTPS | domaine ou IP, certificat auto-signé, durée du certificat |
| Options | script de désinstallation, tests de vérification |

Les valeurs sont validées à la saisie (anti-injection SQL, longueur des mots de
passe, double saisie de confirmation) puis une nouvelle fois avant l'installation.

### 3. Téléchargement / Download

Écran avec Tux qui avance au rythme de la progression réelle:
mise à jour des listes de paquets, Apache et MariaDB, PHP et ses extensions,
utilitaires, puis l'archive GLPI (dernière version détectée sur GitHub).

### 4. Installation

Écran avec Tux animé et la mention **INSTALLATION EN COURS**:
extraction de l'archive, création de la base et de l'utilisateur, sécurisation de
MariaDB, écoute réseau, permissions et répertoires protégés, vhosts Apache et
certificat, configuration PHP, `.htaccess`, pare-feu UFW, script de
désinstallation.

### 5. Récapitulatif / Summary

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

Le script `uninstall-glpi.sh` est généré à la fin de l'installation (option
**Script de désinstallation**). Il possède la même interface console que
l'installateur : panneau d'état à droite, liste des éléments à supprimer à
gauche, bouton **DÉSINSTALLER**, écran de suppression avec Tux et barre de
progression, puis récapitulatif vérifié.

`uninstall-glpi.sh` is generated at the end of the installation (option
**Uninstall script**). It ships the same console interface as the installer:
state panel on the right, list of removable items on the left, **UNINSTALL**
button, removal screen with Tux and a progress bar, then a verified report.

```bash
sudo ./uninstall-glpi.sh
```

### Ce que le script sait supprimer / What the script can remove

| Élément / Item | Détail / Detail |
|----------------|-----------------|
| Fichiers et données | `/var/www/html/glpi`, `/var/lib/glpi`, archive téléchargée, fichiers temporaires |
| Base de données | Base GLPI, utilisateurs `@localhost` et `@%` |
| Configuration Apache | `glpi.conf`, `glpi-ssl.conf`, liens `sites-enabled`, certificat `/etc/ssl/glpi`, journaux `glpi-*.log`, réactivation de `000-default` |
| Tâches planifiées | `/etc/cron.d/glpi*` et les entrées GLPI des crontabs `root` et `www-data` |
| Paquets | Apache, PHP et ses extensions, MariaDB, puis `apt-get autoremove --purge` |
| Configuration système | Restauration des `php.ini` et de `50-server.cnf` sauvegardés avant l'installation |
| Pare-feu | Retrait des règles UFW 80 et 443 (le port 22 reste autorisé) |
| Traces | `/root/.mysql_credentials`, `/var/log/glpi-install.log` |

> [!IMPORTANT]
> C'est la suppression des paquets Apache (ou l'option **Arrêter Apache et
> MariaDB**) qui **libère les ports 80 et 443**. Sans elle, Apache continue de
> tourner et une réinstallation signalera les ports comme occupés.
>
> Removing the Apache packages (or the **Stop Apache and MariaDB** option) is
> what **frees ports 80 and 443**. Without it Apache keeps running and a
> reinstall will report the ports as busy.

Les cases **Supprimer Apache / PHP / MariaDB** sont décochées automatiquement
si un autre site Apache ou une autre base de données est détecté sur la
machine, afin de ne jamais casser un service voisin.

The **Remove Apache / PHP / MariaDB** boxes are unchecked automatically when
another Apache site or another database is detected, so a neighbouring service
is never broken.

### Mode texte / Text mode

```bash
sudo ./uninstall-glpi.sh -y                 # sans interface, options par défaut
sudo ./uninstall-glpi.sh -y --all           # tout, paquets compris
sudo ./uninstall-glpi.sh -y --keep-packages # garde Apache, PHP et MariaDB
sudo ./uninstall-glpi.sh --help
```

Le journal complet est écrit dans `/var/log/glpi-uninstall.log`.

The full log is written to `/var/log/glpi-uninstall.log`.

---

## Fichiers sensibles / Sensitive Files

> [!WARNING]
> Ne partagez JAMAIS ces fichiers / NEVER share these files:
> - `/root/.mysql_credentials` (mot de passe root MySQL)
> - `/var/log/glpi-install.log` (log d'installation)

---

## Dépannage / Troubleshooting

### Erreur "Unable to locate package php-xxx"

Le script n'ajoute à la commande `apt` que les extensions optionnelles connues
de la distribution, et bascule sur une pose paquet par paquet si le lot groupé
échoue. Si l'erreur persiste, les listes de paquets sont probablement obsolètes:

```bash
apt update
apt install software-properties-common -y
```

Pour savoir ce qui a été retenu, la liste exacte est journalisée au début de
l'étape PHP dans `/var/log/glpi-install.log`.

### Le site n'est pas accessible via HTTPS

```bash
# Vérifier Apache
systemctl status apache2

# Vérifier les certificats
ls -l /etc/ssl/glpi/

# Recharger Apache
systemctl reload apache2
```

### `ERROR 1045 (28000): Access denied for user 'root'@'localhost'`

Une installation précédente a défini un mot de passe root MariaDB. L'installateur
essaie automatiquement, dans cet ordre : la connexion par socket, le fichier
`/root/.mysql_credentials`, puis le mot de passe saisi dans le formulaire. Si les
trois échouent, saisissez le mot de passe root existant dans le champ
**Mot de passe root MariaDB**, ou supprimez MariaDB avec
`sudo ./uninstall-glpi.sh` avant de recommencer.

A previous installation set a MariaDB root password. The installer automatically
tries, in this order: socket connection, the `/root/.mysql_credentials` file,
then the password typed in the form. If all three fail, type the existing root
password into the **MariaDB root password** field, or remove MariaDB with
`sudo ./uninstall-glpi.sh` before starting again.

```bash
# retrouver le mot de passe root d'une installation precedente
sudo cat /root/.mysql_credentials
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

### Les ports 80 / 443 sont signalés occupés au lancement

Un serveur web tourne déjà sur la machine, souvent un Apache laissé par une
installation précédente. Vérifiez qui écoute, puis relancez la désinstallation
en cochant **Supprimer Apache (paquets)** ou **Arrêter Apache et MariaDB**.

A web server is already running, usually an Apache left over by a previous
installation. Check who is listening, then run the uninstaller again with
**Remove Apache (packages)** or **Stop Apache and MariaDB** ticked.

```bash
ss -lntp | grep -E ':80|:443'
sudo ./uninstall-glpi.sh
```

---

## Structure du projet / Project Structure

```
glpi-auto/
├── install-glpi-https.sh    # Script d'installation principal / Main install script
├── uninstall-glpi.sh        # Généré par l'installateur, interface incluse
│                            # Generated by the installer, interface included
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
| **Session security** | HTTP-only cookies, SameSite=Lax, and `session.cookie_secure` enabled when the site is served over HTTPS |

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
- [x] Interface bilingue FR/EN avec choix au demarrage / Bilingual FR/EN interface with startup selection
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
