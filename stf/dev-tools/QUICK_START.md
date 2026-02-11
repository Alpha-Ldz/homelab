# 🚀 Quick Start - STF Position Measurement Tool

Guide ultra-rapide pour commencer à utiliser l'outil de mesure de position STF.

## 🎯 En 30 secondes

### Méthode la plus rapide (Console du navigateur)

1. Ouvrez STF dans votre navigateur
2. Appuyez sur `F12` (DevTools)
3. Onglet "Console"
4. Copiez-collez le contenu de `position-measurement.js`
5. Appuyez sur `Entrée`
6. Cliquez sur le bouton 📏 qui apparaît en bas à droite

**C'est tout !** 🎉

## 📏 Utilisation

### Mode Clic (Position d'un point)
- Cliquez sur le bouton 📏 pour activer
- Cliquez sur un point de l'écran
- Les coordonnées s'affichent ET sont copiées :
  ```
  x=123, y=456 (12.30%, 45.60%)
  ```

### Mode Sélection (Zone)
- Activez l'outil (📏 → ✖️)
- Cliquez et maintenez
- Tracez une zone
- Relâchez
- Les dimensions s'affichent ET sont copiées :
  ```
  x=100, y=200, w=300, h=400 (10%, 20%, 30%, 40%)
  ```

## 💡 Méthode permanente (Auto-injection)

Pour que l'outil se charge automatiquement :

1. Installez [Tampermonkey](https://www.tampermonkey.net/)
2. Nouveau script
3. Collez le contenu de `userscript.js`
4. Modifiez la ligne 7 :
   ```javascript
   // @match        http://votre-url-stf.local/*
   ```
5. Sauvegardez (Ctrl+S)

Maintenant l'outil s'active automatiquement sur STF !

## 📖 Informations affichées

### Point :
```
📍 Position
X: 123px (12.30%)
Y: 456px (45.60%)

Device: 1000x1000px
```

### Zone :
```
📐 Sélection
Position:
  X: 100px (10.00%)
  Y: 200px (20.00%)

Dimensions:
  W: 300px (30.00%)
  H: 400px (40.00%)

Device: 1000x1000px
```

## 🔧 Exemples d'utilisation

### Dans Appium
```javascript
const coords = { x: 12.3, y: 45.6 }; // De l'outil

const { width, height } = await driver.getWindowSize();
await driver.touchAction({
    action: 'tap',
    x: Math.round(width * coords.x / 100),
    y: Math.round(height * coords.y / 100)
});
```

### Avec ADB
```bash
# Direct (attention à la résolution)
adb shell input tap 123 456

# Ou avec pourcentage
adb shell input tap $(expr $(adb shell wm size | cut -d' ' -f3 | cut -d'x' -f1) \* 1230 / 10000) 456
```

### API STF
```javascript
// Coordonnées normalisées 0-1
await fetch(`http://stf.local/api/v1/user/devices/${serial}/input`, {
    method: 'POST',
    body: JSON.stringify({
        type: 'touchDown',
        x: 0.123,  // 12.3%
        y: 0.456   // 45.6%
    })
});
```

## 🎨 Personnalisation

Modifiez l'objet `CONFIG` dans le script :

```javascript
const CONFIG = {
    buttonPosition: 'bottom-right',  // 'top-left', 'top-right', 'bottom-left', 'bottom-right'
    copyToClipboard: true,            // Auto-copie
    colors: {
        primary: '#4CAF50',           // Couleur du bouton
    }
};
```

## ❓ Problèmes courants

| Problème | Solution |
|----------|----------|
| Le bouton n'apparaît pas | Rechargez la page, vérifiez la console (F12) |
| L'overlay ne se place pas | Zoom navigateur à 100% |
| Pas de détection de l'écran | Modifiez `findDeviceScreen()` dans le script |
| Script se désactive | Utilisez la méthode Tampermonkey |

## 📦 Fichiers

```
stf/dev-tools/
├── position-measurement.js    # Script complet
├── bookmarklet.txt           # Pour favoris
├── userscript.js             # Pour Tampermonkey
├── QUICK_START.md            # Ce fichier
├── README.md                 # Documentation complète
└── demo.html                 # Démo interactive
```

## 🎓 Pour aller plus loin

Lisez `README.md` pour :
- Installation du bookmarklet
- Configuration avancée
- Plus d'exemples d'intégration
- Dépannage détaillé

---

**Bon développement ! 🚀**
