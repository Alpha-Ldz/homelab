# 📁 Index - STF Position Measurement Tool

Guide rapide de tous les fichiers disponibles dans ce dossier.

## 🚀 Fichiers de démarrage rapide

### QUICK_START.md
**Pour qui :** Débutants qui veulent commencer immédiatement
**Contenu :** Guide en 30 secondes pour installer et utiliser l'outil
**À lire si :** Vous voulez tester rapidement l'outil

### README.md
**Pour qui :** Tous les utilisateurs
**Contenu :** Documentation complète avec toutes les méthodes d'installation
**À lire si :** Vous voulez comprendre toutes les options disponibles

---

## 🛠️ Fichiers d'installation

### position-measurement.js
**Type :** Script JavaScript complet et commenté
**Usage :**
- Copier-coller dans la console du navigateur (F12)
- Base pour personnalisation
**Taille :** ~14 KB
**Fonctionnalités :**
- Détection automatique de l'écran du device
- Mode clic et mode sélection
- Affichage en pixels et pourcentages
- Copie automatique dans le presse-papier
- Gestion du redimensionnement

### bookmarklet.txt
**Type :** Bookmarklet (script minifié)
**Usage :**
- Créer un favori dans votre navigateur
- Coller le contenu dans l'URL du favori
- Cliquer sur le favori quand vous êtes sur STF
**Taille :** ~8.7 KB
**Avantage :** Un clic pour activer l'outil

### userscript.js
**Type :** Script utilisateur pour Tampermonkey/Greasemonkey
**Usage :**
1. Installer Tampermonkey (Chrome/Edge) ou Greasemonkey (Firefox)
2. Créer un nouveau script
3. Copier-coller ce fichier
4. Modifier la ligne `@match` pour votre URL STF
5. Sauvegarder
**Avantage :** Injection automatique à chaque visite sur STF

---

## 📖 Documentation

### EXAMPLES.md
**Pour qui :** Développeurs qui veulent intégrer les mesures dans leurs tests
**Contenu :**
- Exemples Appium/WebDriverIO
- Exemples Python + Appium
- Exemples ADB Shell
- Exemples STF API
- Cas d'usage avancés
**À lire si :** Vous développez des tests automatisés

### demo.html
**Type :** Page HTML interactive
**Usage :**
- Ouvrir dans un navigateur
- Voir une démonstration visuelle de l'outil
- Comprendre les fonctionnalités avec des exemples visuels
**Avantage :** Interface visuelle pour apprendre

### INDEX.md
**Type :** Ce fichier
**Usage :** Naviguer entre les différents fichiers de documentation

---

## 🎯 Quelle méthode choisir ?

### Je veux tester rapidement (< 2 minutes)
→ **Lisez :** QUICK_START.md
→ **Utilisez :** position-measurement.js (console du navigateur)

### Je veux une solution permanente
→ **Lisez :** README.md (section Tampermonkey)
→ **Utilisez :** userscript.js

### Je veux un accès rapide sans installation
→ **Lisez :** README.md (section Bookmarklet)
→ **Utilisez :** bookmarklet.txt

### Je veux intégrer dans mes tests
→ **Lisez :** EXAMPLES.md
→ **Utilisez :** Les exemples de code correspondant à votre framework

### Je veux personnaliser l'outil
→ **Lisez :** README.md (section Configuration)
→ **Utilisez :** position-measurement.js (modifiez l'objet CONFIG)

---

## 📊 Comparaison des méthodes

| Méthode | Installation | Persistance | Facilité | Personnalisation |
|---------|--------------|-------------|----------|------------------|
| Console | Aucune | Temporaire | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Bookmarklet | 1 minute | Permanente* | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Tampermonkey | 3 minutes | Automatique | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

*Permanente = Le favori reste, mais il faut cliquer dessus à chaque fois

---

## 🔍 Structure des fichiers

```
stf/dev-tools/
│
├── 📘 Documentation
│   ├── INDEX.md              # Ce fichier - Index de navigation
│   ├── README.md             # Documentation complète
│   ├── QUICK_START.md        # Guide de démarrage rapide
│   └── EXAMPLES.md           # Exemples d'intégration
│
├── 🛠️ Scripts d'installation
│   ├── position-measurement.js   # Script complet
│   ├── bookmarklet.txt           # Pour favoris
│   └── userscript.js             # Pour Tampermonkey
│
└── 🎨 Démonstration
    └── demo.html                  # Page de démo interactive
```

---

## 🎓 Parcours d'apprentissage recommandé

### Niveau 1 : Découverte (5 minutes)
1. Lire QUICK_START.md
2. Tester avec la console du navigateur
3. Essayer le mode clic et le mode sélection

### Niveau 2 : Installation (10 minutes)
1. Lire README.md (sections Installation)
2. Choisir votre méthode préférée
3. Installer l'outil de manière permanente

### Niveau 3 : Intégration (30 minutes)
1. Ouvrir EXAMPLES.md
2. Trouver les exemples pour votre framework
3. Adapter le code à votre projet
4. Tester avec vos devices

### Niveau 4 : Maîtrise (1 heure)
1. Lire README.md complet
2. Personnaliser la configuration
3. Créer vos propres helpers
4. Documenter vos coordonnées

---

## 💡 Conseils d'utilisation

### Pour le développement
- Utilisez le **bookmarklet** ou **Tampermonkey** pour un accès rapide
- Stockez vos coordonnées dans un fichier JSON ou des constantes
- Créez des helpers pour votre framework préféré

### Pour les tests automatisés
- Utilisez toujours les **pourcentages** pour la portabilité
- Consultez EXAMPLES.md pour des patterns réutilisables
- Créez des Page Objects avec les coordonnées

### Pour le partage avec l'équipe
- Partagez ce dossier complet
- Documentez vos coordonnées avec des screenshots
- Créez un guide spécifique à votre application

---

## ❓ FAQ Rapide

**Q: Quel fichier dois-je utiliser en premier ?**
R: QUICK_START.md pour commencer en 30 secondes

**Q: Comment rendre l'outil permanent ?**
R: Utilisez userscript.js avec Tampermonkey

**Q: Où trouver des exemples de code ?**
R: EXAMPLES.md contient des exemples pour tous les frameworks populaires

**Q: Comment personnaliser les couleurs du bouton ?**
R: Modifiez l'objet CONFIG dans position-measurement.js

**Q: L'outil fonctionne-t-il avec d'autres outils que STF ?**
R: Oui, il peut fonctionner avec n'importe quelle interface web affichant un device

---

## 🔗 Liens rapides

- [Documentation STF](https://github.com/openstf/stf)
- [API STF](https://github.com/openstf/stf/blob/master/doc/API.md)
- [Tampermonkey](https://www.tampermonkey.net/)
- [Appium](https://appium.io/)

---

**Bon développement ! 🚀**

Pour toute question, consultez d'abord README.md et EXAMPLES.md
