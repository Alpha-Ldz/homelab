# STF Position Measurement Tool

Outil de mesure de position pour le développement avec STF (Smartphone Test Farm).

## Fonctionnalités

✨ **Mode Clic** : Cliquez sur l'écran du device pour obtenir la position exacte
- Coordonnées en pixels (x, y)
- Coordonnées en pourcentage (%)
- Copie automatique dans le presse-papier

📐 **Mode Sélection** : Tracez une zone pour obtenir ses dimensions
- Position de départ (x, y)
- Dimensions (largeur, hauteur)
- Tout en pixels ET en pourcentage
- Copie automatique dans le presse-papier

## Méthodes d'installation

### Méthode 1 : Bookmarklet (Recommandé pour usage ponctuel)

1. Créez un nouveau favori dans votre navigateur
2. Nommez-le "STF Position Tool"
3. Dans l'URL, collez le contenu du fichier `bookmarklet.txt`
4. Sauvegardez

**Utilisation** :
- Ouvrez STF dans votre navigateur
- Cliquez sur le favori "STF Position Tool"
- Un bouton 📏 apparaît dans le coin inférieur droit

### Méthode 2 : Console du navigateur (Usage temporaire)

1. Ouvrez STF dans votre navigateur
2. Appuyez sur F12 pour ouvrir les DevTools
3. Allez dans l'onglet "Console"
4. Copiez-collez le contenu de `position-measurement.js`
5. Appuyez sur Entrée

### Méthode 3 : Tampermonkey/Greasemonkey (Injection automatique)

1. Installez [Tampermonkey](https://www.tampermonkey.net/) (Chrome/Edge) ou [Greasemonkey](https://www.greasespot.net/) (Firefox)
2. Cliquez sur l'icône de l'extension
3. "Create a new script" / "Créer un nouveau script"
4. Collez le contenu de `userscript.js`
5. Modifiez la ligne `@match` pour correspondre à votre URL STF
6. Sauvegardez (Ctrl+S)

**Avantage** : Le script s'injecte automatiquement à chaque fois que vous ouvrez STF !

### Méthode 4 : Injection dans l'image Docker (Permanent)

Pour une intégration permanente dans votre déploiement STF :

```bash
# Créer un Dockerfile personnalisé basé sur STF
cd ~/homelab/stf/dev-tools
# Suivre les instructions dans custom-stf-image.md
```

## Utilisation

1. **Activer l'outil** : Cliquez sur le bouton 📏 (il devient rouge ✖️)

2. **Mode Clic** :
   - Cliquez sur un point de l'écran
   - Les coordonnées s'affichent
   - Automatiquement copié : `x=123, y=456 (12.3%, 45.6%)`

3. **Mode Sélection** :
   - Cliquez et maintenez sur l'écran
   - Tracez une zone en déplaçant la souris
   - Relâchez pour voir les dimensions
   - Automatiquement copié : `x=100, y=200, w=300, h=400 (10%, 20%, 30%, 40%)`

4. **Désactiver** : Cliquez sur le bouton rouge ✖️

## Informations affichées

### Pour un point :
```
📍 Position
X: 123px (12.30%)
Y: 456px (45.60%)

Device: 1000x1000px
```

### Pour une zone :
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

## Configuration

Vous pouvez personnaliser le script en modifiant l'objet `CONFIG` dans `position-measurement.js` :

```javascript
const CONFIG = {
    buttonPosition: 'bottom-right',  // Position du bouton
    copyToClipboard: true,            // Copie automatique
    showTooltip: true,                // Afficher l'info-bulle
    colors: {
        primary: '#4CAF50',           // Couleur du bouton
        overlay: 'rgba(76, 175, 80, 0.3)',
        border: '#4CAF50',
        text: '#000000'
    }
};
```

### Options de position du bouton :
- `'top-left'` : En haut à gauche
- `'top-right'` : En haut à droite
- `'bottom-left'` : En bas à gauche
- `'bottom-right'` : En bas à droite (par défaut)

## Exemples d'utilisation dans vos tests

### Avec Appium/WebDriverIO
```javascript
// Utilisez les coordonnées en pourcentage pour plus de portabilité
const coords = { x: 12.3, y: 45.6 }; // Obtenu avec l'outil

// Méthode 1 : Calcul des pixels selon la résolution
const width = driver.getWindowSize().width;
const height = driver.getWindowSize().height;
await driver.touchAction({
    action: 'tap',
    x: Math.round(width * coords.x / 100),
    y: Math.round(height * coords.y / 100)
});

// Méthode 2 : Utiliser les coordonnées normalisées (0-1)
await driver.touchPerform([{
    action: 'tap',
    options: {
        x: coords.x / 100,
        y: coords.y / 100
    }
}]);
```

### Avec adb shell input
```bash
# Pixels directs (attention : dépend de la résolution)
adb shell input tap 123 456

# Ou avec calcul dynamique
SCREEN_WIDTH=$(adb shell wm size | cut -d' ' -f3 | cut -d'x' -f1)
SCREEN_HEIGHT=$(adb shell wm size | cut -d' ' -f3 | cut -d'x' -f2)
X=$((SCREEN_WIDTH * 1230 / 10000))  # 12.30%
Y=$((SCREEN_HEIGHT * 4560 / 10000)) # 45.60%
adb shell input tap $X $Y
```

### Avec STF API
```javascript
// Via l'API STF pour contrôler le device
const position = { x: 0.123, y: 0.456 }; // Coordonnées normalisées (0-1)

await fetch(`http://stf.local/api/v1/user/devices/${serial}/input`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        type: 'touchDown',
        contact: 0,
        x: position.x,
        y: position.y,
        pressure: 0.5
    })
});
```

## Raccourcis clavier (à venir)

- `T` : Toggle l'outil (activer/désactiver)
- `C` : Copier les dernières coordonnées
- `ESC` : Désactiver l'outil

## Dépannage

### Le bouton n'apparaît pas
- Vérifiez que le script s'est bien exécuté (F12 > Console)
- Essayez de recharger la page
- Vérifiez que vous êtes bien sur une page STF

### L'overlay ne se place pas correctement
- Le script cherche automatiquement l'écran du device
- Si la détection échoue, modifiez la fonction `findDeviceScreen()` dans le script
- Inspectez l'élément de l'écran (F12) et ajoutez son sélecteur CSS

### Les mesures sont incorrectes
- Assurez-vous que le zoom du navigateur est à 100%
- Vérifiez que l'écran du device n'est pas redimensionné dynamiquement

### Le script se désactive après navigation
- Utilisez la méthode Tampermonkey pour une injection automatique
- Ou re-cliquez sur le bookmarklet après chaque navigation

## Contribution

Le script est modulaire et facile à étendre. Voici quelques idées :

- [ ] Ajout de raccourcis clavier
- [ ] Historique des mesures
- [ ] Export des coordonnées en JSON/CSV
- [ ] Mode grille pour alignement
- [ ] Règle virtuelle
- [ ] Support de rotations d'écran

## Licence

Libre d'utilisation pour le développement avec STF.

## Liens utiles

- [STF Documentation](https://github.com/openstf/stf)
- [STF API](https://github.com/openstf/stf/blob/master/doc/API.md)
- [Appium Documentation](https://appium.io/docs/en/latest/)
