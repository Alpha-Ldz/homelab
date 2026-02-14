# STF Position Measurement Tool

Outil de mesure de position pour le développement avec STF.

## Fonctionnalités

- **Clic simple**: affiche la position du point (px et %)
- **Sélection (drag)**: affiche la zone et ses dimensions (px et %)
- **Toggle avec bouton flottant** (📏)
- **Copie automatique** dans le presse-papier

## Utilisation rapide

### Méthode 1: Console du navigateur (Le plus simple)

1. Ouvrez la page STF avec un device
2. Ouvrez la console de développement (F12)
3. Copiez-collez le contenu du fichier `position-measurement.js`
4. Appuyez sur Entrée
5. Un bouton 📏 apparaît en bas à droite

### Méthode 2: Userscript (Chargement automatique)

1. Installez **Tampermonkey** (Chrome/Edge) ou **Greasemonkey** (Firefox)
2. Créez un nouveau script
3. Copiez le contenu de `userscript.js`
4. Modifiez la ligne `@match` pour votre URL STF:
   ```javascript
   // @match        http://stf.local/*
   ```
5. Le script se charge automatiquement sur les pages STF

## Utilisation de l'outil

1. Cliquez sur 📏 pour activer le mode mesure
2. **Clic simple** → coordonnées (px et %)
3. **Drag & drop** → dimensions de la zone
4. Coordonnées copiées automatiquement
5. Cliquez sur ✖️ pour désactiver

## Configuration

Modifiez au début du script:

```javascript
const CONFIG = {
    buttonPosition: 'bottom-right',  // top-left, top-right, bottom-left, bottom-right
    copyToClipboard: true,
    colors: {
        primary: '#4CAF50',
        overlay: 'rgba(76, 175, 80, 0.3)',
        border: '#4CAF50'
    }
};
```

## Fichiers

- `position-measurement.js` - Script standalone
- `userscript.js` - Version Tampermonkey/Greasemonkey
- `README.md` - Ce fichier
