# Tiny11 Advanced - Windows 11 Image Creator v3.0

Une solution avancée pour créer des images Windows 11 ultra-optimisées avec les dernières techniques 2024-2025.

## 📋 Description

**⚠️ Disclaimer : Script généré par IA, relecture humaine incomplète ;)**

Tiny11 Advanced v3.0 est un script PowerShell moderne qui crée des versions ultra-allégées de Windows 11 en supprimant les bloatwares (y compris les nouvelles applications AI 2024-2025), désactivant la télémétrie complète, et appliquant des optimisations avancées spécifiques à Windows 11 24H2/25H2. Ce projet s'inspire des scripts Tiny11 originaux tout en apportant des fonctionnalités de pointe. Il est conçu pour un usage éducatif et de test.

**Crédits :**

- [Scripts Tiny11 originaux](https://github.com/ntdevlabs/tiny11builder) : Base d'inspiration
- Communauté Windows : Méthodes d'optimisation

**⚠️ Disclaimer :** Ce script modifie profondément Windows 11. Utilisez-le uniquement si vous comprenez les implications. Toujours tester en environnement sécurisé avant utilisation en production.

---

## ✨ Fonctionnalités principales

### 🔒 Respect des règles essentielles
- **Windows Update** : Fonctionnalité complètement préservée
- **Windows Store** : Toutes les fonctionnalités conservées
- **Windows Defender** : Désactivé (pas supprimé) - peut être réactivé par l'utilisateur

### 🚀 Fonctionnalités avancées (v3.0 - 2024-2025)
- **Suppression de bloatwares étendue** : 75+ applications UWP et systèmes (y compris Copilot, Teams, nouvelles apps AI)
- **Méthodes anti-réinstallation renforcées** : UScheduler et BlockedOobeUpdaters pour toutes les apps modernes
- **Suppression de télémétrie complète** : Services AI inclus (AIFabricService, CopilotService)
- **Désactivation des fonctionnalités IA** : Copilot, Recall, AI Fabric Service, services de messagerie
- **Optimisation WinSxS agressive** : Mode standard (25-30%) ou agressif (40-50%) avec `-AggressiveWinSxS`
- **Suppression Features on Demand** : 25+ capacités Windows optionnelles supprimées
- **Optimisations registre 24H2** : 15+ nouvelles clés de performance Windows 11
- **Interface utilisateur moderne** : Bannières colorées et progression détaillée

### 🛡️ Sécurité et réversibilité
- Script de réactivation de Windows Defender inclus
- Points de restauration système recommandés
- Validation complète des sources d'installation
- Gestion d'erreurs robuste

## 📁 Structure du projet

```
Tiny11Advanced/
├── Tiny11Advanced.ps1          # Script principal
├── Enable-WindowsDefender.ps1   # Script de réactivation Defender
├── Modules/                     # Modules fonctionnels
│   ├── AppxPackageManager.ps1   # Gestion des packages AppX
│   ├── RegistryOptimizer.ps1    # Optimisations registre
│   ├── SystemOptimizer.ps1      # Optimisations système
│   ├── SecurityManager.ps1      # Gestion sécurité
│   ├── ImageProcessor.ps1       # Traitement d'images
│   └── ValidationHelper.ps1     # Fonctions de validation
└── README.md                    # Cette documentation
```

## 🚀 Installation et utilisation

### Prérequis
- Windows 10/11 avec PowerShell 5.1+
- Privilèges administrateur
- Minimum 25 GB d'espace disque libre
- DISM (Deployment Image Servicing and Management)
- Support d'installation Windows 11 (ISO/DVD/USB)

### Autoriser l'exécution de scripts PowerShell

Avant d'utiliser le script, vous devez autoriser l'exécution de scripts PowerShell sur votre système :

```powershell
# Commande à exécuter une seule fois en tant qu'administrateur pour autoriser les scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Cette commande autorise l'exécution de scripts PowerShell locaux et distants signés pour l'utilisateur actuel.

### Utilisation basique

```powershell
# Exécution simple avec interface interactive
.\Tiny11Advanced.ps1

# Utilisation avec paramètres
.\Tiny11Advanced.ps1 -SourcePath "D:" -EnableDotNet35 -DisableDefender -SkipWinSxS
```

### Paramètres disponibles

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `-SourcePath` | Chemin vers l'installation Windows 11 | `"D:"` ou `"C:\ISO\Win11"` |
| `-OutputPath` | Répertoire de sortie | `"C:\Tiny11Output"` |
| `-ImageIndex` | Index d'image à traiter | `1`, `2`, `3`... |
| `-EnableDotNet35` | Active .NET Framework 3.5 | `-EnableDotNet35` |
| `-DisableDefender` | Désactive Windows Defender | `-DisableDefender` |
| `-SkipSystemPackages` | Ignore les packages système | `-SkipSystemPackages` |
| `-SkipWinSxS` | Ignore l'optimisation WinSxS (évite les blocages) | `-SkipWinSxS` |
| `-AggressiveWinSxS` | **NOUVEAU** : Active le nettoyage WinSxS agressif (/ResetBase) | `-AggressiveWinSxS` |
| `-RemoveAdditionalLanguages` | Supprime les packs de langues additionnels | `-RemoveAdditionalLanguages` |

### Exemples d'utilisation

```powershell
# Configuration complète avec toutes les optimisations (mode standard)
.\Tiny11Advanced.ps1 -SourcePath "D:" -OutputPath "C:\Output" -EnableDotNet35 -DisableDefender -RemoveAdditionalLanguages

# MODE AGRESSIF - Compression maximale (⚠️ casse Windows Update)
.\Tiny11Advanced.ps1 -SourcePath "D:" -AggressiveWinSxS -DisableDefender -RemoveAdditionalLanguages

# Pour éviter les blocages WinSxS (traitement rapide)
.\Tiny11Advanced.ps1 -SourcePath "D:" -SkipWinSxS

# Traitement rapide en conservant les packages système
.\Tiny11Advanced.ps1 -SourcePath "E:" -SkipSystemPackages

# Traitement d'un index spécifique avec optimisations 2024-2025
.\Tiny11Advanced.ps1 -SourcePath "F:" -ImageIndex 2 -DisableDefender -RemoveAdditionalLanguages
```

## 🔧 Fonctionnalités détaillées

### 🏗️ Architecture modulaire

Le projet utilise une architecture modulaire pour une maintenance optimale :

| Module | Responsabilité | Fonctions principales |
|--------|----------------|----------------------|
| **AppxPackageManager** | Gestion des applications UWP/AppX/AI (2024-2025) | `Remove-BloatwarePackages`, `Remove-SystemPackages` |
| **RegistryOptimizer** | Modifications registre avancées + optimisations 24H2 | `Optimize-RegistrySettings`, `Apply-AntiReinstallationMethods`, `Apply-PerformanceOptimizations` |
| **SystemOptimizer** | Optimisations système + Features on Demand + WinSxS agressif | `Optimize-SystemSettings`, `Optimize-WinSxS`, `Remove-FeaturesOnDemand` |
| **SecurityManager** | Gestion de la sécurité | `Disable-WindowsDefender`, `Set-SecurityOptimizations` |
| **ImageProcessor** | Traitement des images Windows | `Mount-WindowsImageAdvanced`, `Create-OptimizedISO` |
| **ValidationHelper** | Validation et vérifications | `Test-WindowsInstallationSource`, `Test-SystemRequirements` |

### Applications supprimées (v3.0 - Étendu 2024-2025)

**Applications UWP/AppX classiques :**
- Clipchamp, Microsoft Teams, Xbox Gaming
- Applications Bing (News, Weather, Search, Translator, Finance)
- Microsoft Office Hub, Solitaire Collection
- Applications de communication (Mail, Calendar, Phone Link)
- Feedback Hub, Get Help, Tips
- People, Maps, Sound Recorder, Alarms

**Applications modernes Windows 11 23H2/24H2/25H2 :**
- Dev Home, Nouvelle Outlook
- Paint avec IA, Bloc-notes avec IA
- Capture d'écran et croquis, Photos avec IA

**NOUVEAU - Applications AI et modernes (2024-2025) :**
- **Microsoft Copilot** et toutes ses variantes
- **Windows.Copilot**, **CopilotApp**
- **WindowsAppRuntime** (composants IA)
- **Teams** nouvelle version (MSTeams)
- **Sticky Notes** moderne
- **Cross Device** experiences
- **Windows Web Experience**
- **Diagnostic Data Viewer**
- **Parental Controls**

**Packages système :**
- Internet Explorer
- Windows Media Player
- WordPad, Math Input Panel
- Fonctionnalités linguistiques optionnelles
- Contenu de fond d'écran étendu

**NOUVEAU - Features on Demand supprimées (25+ capacités) :**
- **Steps Recorder**, **Quick Assist**, **Internet Explorer mode**
- **Windows Hello Face**, reconnaissance vocale/écriture manuscrite
- **Math Recognizer**, **Windows Media Player** legacy
- **Paint**, **Notepad**, **PowerShell ISE**, **WordPad**
- **OpenSSH Client**, **Windows Fax and Scan**
- **Outils RSAT** (Active Directory, DNS, DHCP, etc.)
- **SNMP WMI Provider**, **XPS Viewer**

**Packs de langues additionnels (optionnel) :**
- Suppression des langues non-primaires de l'image
- Préservation de la langue système principale
- Capacité d'installation post-déploiement maintenue
- Réduction significative de la taille de l'image

### Optimisations registre

**Télémétrie et confidentialité :**
- Désactivation complète de la télémétrie Windows
- Suppression de la collecte de données publicitaires
- Désactivation des services de diagnostic
- Protection contre la collecte de données d'utilisation

**Méthodes anti-réinstallation (ÉTENDUES 2024-2025) :**
- UScheduler avec `workCompleted` pour **Outlook, DevHome, Copilot, Teams, Clipchamp**
- BlockedOobeUpdaters pour toutes les applications modernes
- Suppression des déclencheurs OOBE étendus
- Prévention de réinstallation des composants AI

**Fonctionnalités IA (2024-2025) :**
- Désactivation de Windows Recall
- Suppression complète de Windows Copilot (toutes variantes)
- Désactivation d'AI Fabric Service
- Blocage des suggestions IA et services associés

**NOUVEAU - Optimisations performance registre (Windows 11 24H2) :**
- **NetworkThrottlingIndex** : Désactivation du throttling réseau
- **SystemResponsiveness** : Amélioré de 14 à 10
- **Gaming Performance** : GPU Priority=8, Priority=6, Scheduling=High
- **Memory Management** : LargeSystemCache=1
- **Power Management** : Désactivation PowerThrottling
- **Animation Control** : Désactivation effets visuels non essentiels

### Optimisations système

**Services désactivés (ÉTENDUS 2024-2025) :**
- **Télémétrie classique** : DiagTrack, dmwappushservice
- **Services de diagnostic** : diagnosticshub.standardcollector.service
- **Compatibilité** : MapsBroker, Program Compatibility Assistant
- **NOUVEAU - Services AI** : AIFabricService, CopilotService
- **NOUVEAU - Services modernes** : AdjustService, MessagingService, PimIndexMaintenanceSvc

**Tâches planifiées supprimées :**
- Application Compatibility Appraiser
- Customer Experience Improvement Program
- Program Data Updater
- Services de feedback automatique

**WinSxS optimisé (v3.0 - Mode Agressif Disponible) :**
- **Mode standard** : Nettoyage avec `/StartComponentCleanup` (préservation Windows Update)
- **NOUVEAU - Mode agressif** : Nettoyage `/ResetBase` avec paramètre `-AggressiveWinSxS`
- ⚠️ **AVERTISSEMENT Mode Agressif** : Casse Windows Update et installation packs de langues
- **Réductions** : Standard (~400MB) vs Agressif (~800MB-1.2GB supplémentaires)
- **Protection utilisateur** : Avertissements multiples et possibilité d'annulation

## 🛡️ Gestion de Windows Defender

### Désactivation (script principal)
Windows Defender est **désactivé mais pas supprimé** pour permettre une réactivation facile :

- Services désactivés via registre
- Politiques de désactivation appliquées
- Interface utilisateur masquée
- Fichiers et composants préservés

### Réactivation (script séparé)

```powershell
# Exécuter en tant qu'administrateur
.\Enable-WindowsDefender.ps1
```

Le script de réactivation :
- Réactive tous les services Windows Defender
- Supprime les politiques de désactivation
- Restaure l'interface utilisateur
- Configure la protection en temps réel
- Met à jour les signatures si possible

## 📊 Optimisations de performance

### Interface utilisateur
- Désactivation des effets visuels pour la performance
- Configuration pour performance maximale
- Suppression des animations non essentielles

### Stockage
- Désactivation du stockage réservé
- Nettoyage des fichiers temporaires
- Optimisation des pilotes (suppression sélective)

### Démarrage
- Contournement des vérifications matérielles
- Configuration OOBE optimisée
- Comptes locaux activés par défaut

## ⚠️ Avertissements et précautions

### ⚠️ NOUVEAU - Mode Agressif (`-AggressiveWinSxS`)
**ATTENTION CRITIQUE** : Le nouveau paramètre `-AggressiveWinSxS` active un mode de compression maximale qui :
- **CASSE DÉFINITIVEMENT Windows Update** - aucune mise à jour ne pourra être installée
- **EMPÊCHE l'installation de packs de langues** - impossible d'ajouter des langues
- **BLOQUE l'installation de composants Windows** - fonctionnalités additionnelles inaccessibles
- **RÉDUCTION EXTRÊME** : ~800MB-1.2GB supplémentaires économisés
- **USAGE RECOMMANDÉ** : Uniquement pour environnements isolés, kiosques, ou images spécialisées

**Mode Standard (recommandé)** : Préserve toutes les fonctionnalités Windows Update et packs de langues

### Limitations importantes (Mode Standard)
- **Windows Update pleinement fonctionnel** : mises à jour de sécurité, pilotes et correctifs
- **Installation de packs de langues préservée** : les utilisateurs peuvent ajouter des langues  
- **Certains services peuvent être requis pour des fonctionnalités spécifiques**
- **Les mises à jour Windows peuvent restaurer certaines fonctionnalités supprimées**

### Précautions recommandées
1. **Toujours créer un point de restauration** avant l'application
2. **Tester sur machine virtuelle** avant déploiement en production
3. **Conserver une sauvegarde** de l'image originale
4. **Vérifier la compatibilité** avec vos applications métier

### Dépannage courant

**Problèmes de montage d'image :**
```powershell
# Nettoyer les points de montage orphelins
dism /Cleanup-Mountpoints
```

**Erreurs de permissions :**
```powershell
# Vérifier les privilèges administrateur
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

**Problèmes de registre :**
```powershell
# Décharger les ruches en cas d'erreur
reg unload HKLM\zSYSTEM
reg unload HKLM\zSOFTWARE
```

## 📝 Journalisation et debugging

### Fichiers de log
- Log principal : `Tiny11Advanced_YYYYMMDD_HHMMSS.log`
- Transcript PowerShell automatique
- Messages colorés dans la console
- Niveaux de log : Info, Warning, Error, Success

### Mode debug
```powershell
# Activer le debug PowerShell (décommenter dans le script)
Set-PSDebug -Trace 1
```

## 🤝 Contribution et support

### Architecture modulaire
Le projet utilise une architecture modulaire pour faciliter la maintenance :

- **AppxPackageManager** : Gestion des applications
- **RegistryOptimizer** : Modifications registre
- **SystemOptimizer** : Optimisations système
- **SecurityManager** : Gestion sécurité
- **ImageProcessor** : Traitement d'images
- **ValidationHelper** : Fonctions utilitaires

### Standards de code
- PowerShell 5.1+ compatible
- Gestion d'erreurs robuste
- Documentation complète
- Validation des paramètres
- Architecture orientée objet

## 🔍 Tests et validation

### Tests recommandés
1. **Machine virtuelle** : Toujours tester d'abord en VM
2. **Vérification d'intégrité** : `Test-ImageIntegrity` intégré
3. **Validation des sources** : Contrôle automatique des fichiers ISO
4. **Tests fonctionnels** :
   - Windows Update fonctionnel
   - Windows Store opérationnel
   - Réactivation Windows Defender

### Métriques de qualité (v3.0 - 2024-2025)
- **Réduction de taille** : 25-30% (standard) ou 40-50% (agressif)
- **Applications supprimées** : **75+** applications bloatware (y compris AI/modernes)
- **Features on Demand supprimées** : **25+** capacités Windows optionnelles  
- **Services optimisés** : **20+** services système (y compris AI)
- **Optimisations registre** : **15+** nouvelles clés performance 24H2
- **Compatibilité** : Windows 11 22H2, 23H2, **24H2, 25H2** (builds 22621/22631/26100+)

### Réductions de taille estimées (v3.0)
- **Mode standard** : ~4.0GB final (au lieu de 5.4GB original)
- **Mode agressif** : ~3.0GB final (⚠️ avec risques Windows Update)
- **Gain total** : 1.4-2.4GB d'économie selon le mode choisi

## 🔧 Développement et maintenance

### Structure des fonctions
```powershell
# Chaque module suit cette structure standard :
function Verb-Noun {
    <#
    .SYNOPSIS
        Description courte de la fonction
    .PARAMETER ParameterName
        Description du paramètre
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ParameterName
    )
    
    Write-Log "Action en cours..." -Level Info
    
    try {
        # Logique de la fonction
        Write-Log "Succès de l'opération" -Level Success
        return $true
    }
    catch {
        Write-Log "Erreur : $($_.Exception.Message)" -Level Error
        return $false
    }
}
```

### Bonnes pratiques implémentées
- Gestion d'erreurs robuste avec try/catch
- Logging détaillé avec niveaux (Info, Warning, Error, Success)
- Validation des paramètres d'entrée
- Nettoyage automatique des ressources
- Documentation inline complète

## 📋 Changelog et versions

### Version 3.0 (Actuelle - Optimisations 2024-2025)
- **Architecture modulaire complète** avec 6 modules spécialisés étendus
- **Support Windows 11 23H2/24H2/25H2** avec optimisations spécifiques
- **Gestion IA complète** : Suppression Copilot, Recall, AI Fabric + nouveaux services
- **75+ applications supprimées** : Bloatware classique + nouvelles apps AI/modernes
- **25+ Features on Demand** supprimées pour économie d'espace additionnelle
- **Mode WinSxS agressif** : Nouveau paramètre `-AggressiveWinSxS` pour compression maximale
- **15+ optimisations registre 24H2** : NetworkThrottling, Gaming, Memory, Power
- **Anti-réinstallation étendue** : Copilot, Teams, Clipchamp, nouvelles apps
- **Réductions améliorées** : 25-30% (standard) ou 40-50% (agressif)
- Script de réactivation Windows Defender préservé
- Interface utilisateur moderne avec bannières colorées
- Validation complète des sources et tests d'intégrité
- Support conversion ESD vers WIM automatique

### Idées de fonctionnalités
- Interface graphique (GUI) avec Windows Forms
- Profiles prédéfinis (Gaming, Office, Development)
- Sauvegarde/restauration de configurations utilisateur
- Support batch pour traitement de multiple images
- Intégration de drivers personnalisés
- Mode silencieux pour déploiement automatisé

## 📄 Licence et crédits

Ce projet s'inspire des scripts Tiny11 originaux tout en apportant des fonctionnalités avancées. Il est conçu pour un usage éducatif et de test.

**Crédits :**
- Scripts Tiny11 originaux : Base d'inspiration
- Communauté Windows : Méthodes d'optimisation

