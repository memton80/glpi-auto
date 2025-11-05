# 🔒 Politique de sécurité / Security Policy

---

## 📦 Versions prises en charge / Supported Versions

| Version | Supportée / Supported |
| -------- | --------------------- |
| 2.x.x    | ✅ Oui / Yes          |
| 1.x.x    | ❌ Non / No           |
| < 1.0    | ❌ Non / No           |

Les correctifs de sécurité sont appliqués uniquement sur les versions **stables et récentes**  
(branches `main` ou `2.x`).

Security updates are only applied to **stable and recent** versions  
(branches `main` or `2.x`).

---

## 🐛 Signaler une vulnérabilité / Reporting a Vulnerability

### 🇫🇷 En français :
Si tu découvres une faille de sécurité dans **GLPI-Auto**, **ne crée pas d’issue publique**.  
Merci d’utiliser l’une des méthodes suivantes :

- 📬 Via le **[formulaire de sécurité GitHub](https://github.com/memton80/glpi-auto/security/advisories)**
- 🔗 Ou en contactant directement le mainteneur : **[@memton80](https://github.com/memton80)**

#### ⏱ Délai de réponse :
- Réponse initiale sous **72 heures**
- Analyse complète sous **7 jours**
- Correctif publié sous **14 jours** (en général)

---

### 🇬🇧 In English:
If you discover a security vulnerability in **GLPI-Auto**, **please do not open a public issue**.  
Use one of the following methods instead:

- 📬 Through the **[GitHub Security Advisory form](https://github.com/memton80/glpi-auto/security/advisories)**
- 🔗 Or contact the maintainer directly: **[@memton80](https://github.com/memton80)**

#### ⏱ Expected response time:
- Initial response within **72 hours**
- Full investigation within **7 days**
- Patch released within **14 days** (typically)

---

## 🧩 Processus après signalement / After-Report Process

| Étape / Step | Description |
| ------------- | ----------- |
| 🔍 **Analyse / Review** | La faille est évaluée et reproduite en interne.<br>The issue is reviewed and reproduced internally. |
| 🧱 **Correctif / Fix** | Un correctif est développé sur une branche privée.<br>A fix is developed on a private branch. |
| 🚀 **Publication / Release** | Une nouvelle version est publiée avec un avis de sécurité.<br>A new version is released with a security advisory. |
| 💬 **Crédits / Credits** | Le contributeur est mentionné s’il le souhaite.<br>Reporter is credited if desired. |

---

## 🧱 Bonnes pratiques / Best Practices

### 🇫🇷 Pour les contributeurs :
- 🚫 Ne partage **aucune donnée sensible** (tokens, mots de passe, logs internes).
- 🧪 Teste toujours les scripts dans un **environnement isolé** (VM, Docker, sandbox).
- 🔄 Utilise des **pull requests** pour les améliorations, pas pour publier des failles.

### 🇬🇧 For contributors:
- 🚫 Do **not share sensitive information** (tokens, passwords, internal logs).
- 🧪 Always test scripts in an **isolated environment** (VM, Docker, sandbox).
- 🔄 Use **pull requests** for improvements, not to publicly disclose vulnerabilities.

---

© 2025 [memton80](https://github.com/memton80) — **GLPI-Auto**
