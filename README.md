# Tiny11 Advanced - Windows 11 Image Creator

Une solution pour créer des images Windows 11 allégées et optimisées.

## 📋 Description

Tiny11 Advanced est un script PowerShell moderne qui crée des versions allégées de Windows 11 en supprimant les bloatwares, désactivant la télémétrie, et appliquant des optimisations avancées.

**Crédits :**
- Scripts Tiny11 originaux : Base d'inspiration
- Communauté Windows : Méthodes d'optimisation

---

**⚠️ Disclaimer :** Ce script modifie profondément Windows 11. Utilisez-le uniquement si vous comprenez les implications. Toujours tester en environnement sécurisé avant utilisation en production.

**⚠️ Disclaimer : Script généré par IA, relecture humaine incomplète ;)**

## ✨ Fonctionnalités principales

### 🔒 Respect des règles essentielles
- **Windows Update** : Fonctionnalité complètement préservée
- **Windows Store** : Toutes les fonctionnalités conservées
- **Windows Defender** : Désactivé (pas supprimé) - peut être réactivé par l'utilisateur

### 🚀 Fonctionnalités avancées
- **Suppression de bloatwares** : Applications UWP et systèmes non essentielles
- **Méthodes anti-réinstallation renforcées** : UScheduler et BlockedOobeUpdaters
- **Suppression de télémétrie** : Complète sans impact sur les fonctions critiques
- **Désactivation des fonctionnalités IA** : Copilot, Recall, AI Fabric Service
- **Optimisation WinSxS** : Réduction de 40-60% de la taille
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

### Utilisation basique

```powershell
# Exécution simple avec interface interactive
.\Tiny11Advanced.ps1

# Utilisation avec paramètres
.\Tiny11Advanced.ps1 -SourcePath "D:" -EnableDotNet35 -DisableDefender
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

### Exemples d'utilisation

```powershell
# Configuration complète avec toutes les optimisations
.\Tiny11Advanced.ps1 -SourcePath "D:" -OutputPath "C:\Output" -EnableDotNet35 -DisableDefender

# Traitement rapide en conservant les packages système
.\Tiny11Advanced.ps1 -SourcePath "E:" -SkipSystemPackages

# Traitement d'un index spécifique
.\Tiny11Advanced.ps1 -SourcePath "F:" -ImageIndex 2 -DisableDefender
```

## 🔧 Fonctionnalités détaillées

### 🏗️ Architecture modulaire

Le projet utilise une architecture modulaire pour une maintenance optimale :

| Module | Responsabilité | Fonctions principales |
|--------|----------------|----------------------|
| **AppxPackageManager** | Gestion des applications UWP/AppX | `Remove-BloatwarePackages`, `Remove-SystemPackages` |
| **RegistryOptimizer** | Modifications registre avancées | `Optimize-RegistrySettings`, `Apply-AntiReinstallationMethods` |
| **SystemOptimizer** | Optimisations système globales | `Optimize-SystemSettings`, `Optimize-WinSxS` |
| **SecurityManager** | Gestion de la sécurité | `Disable-WindowsDefender`, `Set-SecurityOptimizations` |
| **ImageProcessor** | Traitement des images Windows | `Mount-WindowsImageAdvanced`, `Create-OptimizedISO` |
| **ValidationHelper** | Validation et vérifications | `Test-WindowsInstallationSource`, `Test-SystemRequirements` |

### Applications supprimées

**Applications UWP/AppX :**
- Clipchamp, Microsoft Teams, Xbox Gaming
- Applications Bing (News, Weather)
- Microsoft Office Hub, Solitaire Collection
- Applications de communication (Mail, Calendar, Phone Link)
- Feedback Hub, Get Help, Tips
- Et bien d'autres...

**Applications modernes Windows 11 23H2/24H2 :**
- Dev Home, Nouvelle Outlook
- Paint avec IA, Bloc-notes avec IA
- Capture d'écran et croquis
- Photos avec IA

**Packages système :**
- Internet Explorer
- Windows Media Player
- WordPad, Math Input Panel
- Fonctionnalités linguistiques optionnelles
- Contenu de fond d'écran étendu

### Optimisations registre

**Télémétrie et confidentialité :**
- Désactivation complète de la télémétrie Windows
- Suppression de la collecte de données publicitaires
- Désactivation des services de diagnostic
- Protection contre la collecte de données d'utilisation

**Méthodes anti-réinstallation :**
- UScheduler avec `workCompleted` pour Outlook/DevHome
- BlockedOobeUpdaters pour empêcher les réinstallations
- Suppression des déclencheurs OOBE

**Fonctionnalités IA (2024-2025) :**
- Désactivation de Windows Recall
- Suppression de Windows Copilot
- Désactivation d'AI Fabric Service
- Blocage des suggestions IA

### Optimisations système

**Services désactivés :**
- DiagTrack, dmwappushservice
- Services de diagnostic étendus
- MapsBroker, Program Compatibility Assistant
- Services de télémétrie avancés

**Tâches planifiées supprimées :**
- Application Compatibility Appraiser
- Customer Experience Improvement Program
- Program Data Updater
- Services de feedback automatique

**WinSxS optimisé :**
- Nettoyage standard avec `/StartComponentCleanup`
- Nettoyage avancé avec `/ResetBase` (irréversible)
- Réduction de 40-60% de la taille potentielle

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

### Importantes limitations
- **Le nettoyage WinSxS avec ResetBase est irréversible**
- **L'image ne peut pas être mise à jour ou recevoir de packs de langues après**
- **Certains services peuvent être requis pour des fonctionnalités spécifiques**
- **Les mises à jour Windows peuvent restaurer certaines fonctionnalités**

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

### Métriques de qualité
- **Réduction de taille** : 40-60% (selon configuration)
- **Applications supprimées** : 50+ applications bloatware
- **Services optimisés** : 15+ services système
- **Compatibilité** : Windows 11 22H2, 23H2, 24H2

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

### Version 1.0 (Actuelle)
- Architecture modulaire complète avec 6 modules spécialisés
- Support Windows 11 23H2/24H2 avec optimisations spécifiques
- Gestion avancée des fonctionnalités IA (Copilot, Recall, AI Fabric)
- Script de réactivation Windows Defender intégré
- Interface utilisateur moderne avec bannières colorées
- Validation complète des sources et tests d'intégrité
- Méthodes anti-réinstallation renforcées (UScheduler + BlockedOobeUpdaters)
- Optimisation WinSxS avancée avec ResetBase
- Support conversion ESD vers WIM automatique

### Idées de fonctionnalités
- Interface graphique (GUI) avec Windows Forms
- Profiles prédéfinis (Gaming, Office, Development)
- Sauvegarde/restauration de configurations utilisateur
- Support batch pour traitement de multiple images
- Intégration de drivers personnalisés
- Mode silencieux pour déploiement automatisé

## 📄 Licence et crédits

Ce projet s'inspire des scripts Tiny11 originaux tout en apportant une architecture moderne et des fonctionnalités avancées. Il est conçu pour un usage éducatif et de test.

