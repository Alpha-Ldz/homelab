# 📚 Exemples d'utilisation - STF Position Measurement Tool

Collection d'exemples pratiques pour différents frameworks et cas d'usage.

## Table des matières
- [Appium / WebDriverIO](#appium--webdriverio)
- [Python + Appium](#python--appium)
- [ADB Shell](#adb-shell)
- [STF API](#stf-api)
- [Selenium + Appium](#selenium--appium)
- [Détente / Robot Framework](#detente--robot-framework)
- [Cas d'usage avancés](#cas-dusage-avancés)

---

## Appium / WebDriverIO

### Exemple 1 : Tap sur un bouton
```javascript
// Coordonnées obtenues avec l'outil: x=150, y=500 (15%, 50%)

const coords = { x: 15, y: 50 }; // Pourcentages

// Méthode 1 : Avec calcul manuel
const { width, height } = await driver.getWindowSize();
await driver.touchAction({
    action: 'tap',
    x: Math.round(width * coords.x / 100),
    y: Math.round(height * coords.y / 100)
});

// Méthode 2 : Avec coordonnées normalisées
await driver.touchPerform([{
    action: 'tap',
    options: {
        x: coords.x / 100,  // 0.15
        y: coords.y / 100   // 0.50
    }
}]);
```

### Exemple 2 : Swipe dans une zone
```javascript
// Zone obtenue: x=100, y=300, w=200, h=400 (10%, 30%, 20%, 40%)

const zone = {
    x: 10, y: 30,
    width: 20, height: 40
};

const { width, height } = await driver.getWindowSize();

// Swipe de haut en bas dans la zone
const startX = width * (zone.x + zone.width / 2) / 100;  // Centre X
const startY = height * zone.y / 100;                     // Haut
const endY = height * (zone.y + zone.height) / 100;      // Bas

await driver.touchPerform([
    { action: 'press', options: { x: startX, y: startY } },
    { action: 'wait', options: { ms: 500 } },
    { action: 'moveTo', options: { x: startX, y: endY } },
    { action: 'release' }
]);
```

### Exemple 3 : Multi-touch / Pinch
```javascript
// Zone obtenue: x=100, y=200, w=300, h=400

const { width, height } = await driver.getWindowSize();

const centerX = (100 + 150) * width / 1000;  // Centre de la zone
const centerY = (200 + 200) * height / 1000;

// Pinch (zoom out)
await driver.multiTouchPerform([
    // Doigt 1
    [
        { action: 'press', options: { x: centerX - 50, y: centerY - 50 } },
        { action: 'moveTo', options: { x: centerX - 10, y: centerY - 10 } },
        { action: 'release' }
    ],
    // Doigt 2
    [
        { action: 'press', options: { x: centerX + 50, y: centerY + 50 } },
        { action: 'moveTo', options: { x: centerX + 10, y: centerY + 10 } },
        { action: 'release' }
    ]
]);
```

---

## Python + Appium

### Exemple 1 : Classe helper pour les coordonnées
```python
from appium import webdriver
from appium.webdriver.common.touch_action import TouchAction

class PositionHelper:
    def __init__(self, driver):
        self.driver = driver
        size = driver.get_window_size()
        self.width = size['width']
        self.height = size['height']

    def tap_percent(self, x_percent, y_percent):
        """Tap avec coordonnées en pourcentage"""
        x = int(self.width * x_percent / 100)
        y = int(self.height * y_percent / 100)
        TouchAction(self.driver).tap(x=x, y=y).perform()

    def tap_pixels(self, x, y):
        """Tap avec coordonnées en pixels"""
        TouchAction(self.driver).tap(x=x, y=y).perform()

    def swipe_zone(self, x_percent, y_percent, width_percent, height_percent, direction='down'):
        """Swipe dans une zone définie"""
        x = int(self.width * x_percent / 100)
        y = int(self.height * y_percent / 100)
        w = int(self.width * width_percent / 100)
        h = int(self.height * height_percent / 100)

        center_x = x + w // 2

        if direction == 'down':
            start_y = y
            end_y = y + h
        elif direction == 'up':
            start_y = y + h
            end_y = y

        TouchAction(self.driver) \
            .press(x=center_x, y=start_y) \
            .wait(500) \
            .move_to(x=center_x, y=end_y) \
            .release() \
            .perform()

# Utilisation
driver = webdriver.Remote('http://localhost:4723/wd/hub', desired_caps)
helper = PositionHelper(driver)

# Coordonnées de l'outil: x=150, y=500 (15%, 50%)
helper.tap_percent(15, 50)

# Zone de scroll: x=100, y=300, w=200, h=400 (10%, 30%, 20%, 40%)
helper.swipe_zone(10, 30, 20, 40, direction='up')
```

### Exemple 2 : Vérification de zone
```python
def is_element_in_zone(element, zone_percent):
    """Vérifie si un élément est dans une zone"""
    location = element.location
    size = element.size

    elem_x_percent = (location['x'] / self.width) * 100
    elem_y_percent = (location['y'] / self.height) * 100

    return (zone_percent['x'] <= elem_x_percent <= zone_percent['x'] + zone_percent['width'] and
            zone_percent['y'] <= elem_y_percent <= zone_percent['y'] + zone_percent['height'])

# Utilisation
zone = {'x': 10, 'y': 30, 'width': 20, 'height': 40}
button = driver.find_element_by_id('submit_button')

if is_element_in_zone(button, zone):
    print("Le bouton est dans la zone de scroll")
```

---

## ADB Shell

### Exemple 1 : Tap avec calcul dynamique
```bash
#!/bin/bash

# Fonction pour obtenir la résolution
get_resolution() {
    adb shell wm size | grep -oE '[0-9]+x[0-9]+' | head -1
}

# Fonction pour tap avec pourcentages
tap_percent() {
    local x_percent=$1
    local y_percent=$2

    local resolution=$(get_resolution)
    local width=$(echo $resolution | cut -d'x' -f1)
    local height=$(echo $resolution | cut -d'x' -f2)

    local x=$((width * x_percent / 100))
    local y=$((height * y_percent / 100))

    echo "Tapping at $x,$y (${x_percent}%, ${y_percent}%) on ${width}x${height}"
    adb shell input tap $x $y
}

# Coordonnées de l'outil: 15%, 50%
tap_percent 15 50
```

### Exemple 2 : Swipe dans une zone
```bash
#!/bin/bash

swipe_zone() {
    local x_percent=$1
    local y_percent=$2
    local width_percent=$3
    local height_percent=$4
    local direction=$5  # up, down, left, right

    local resolution=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | head -1)
    local screen_width=$(echo $resolution | cut -d'x' -f1)
    local screen_height=$(echo $resolution | cut -d'x' -f2)

    local x=$((screen_width * x_percent / 100))
    local y=$((screen_height * y_percent / 100))
    local w=$((screen_width * width_percent / 100))
    local h=$((screen_height * height_percent / 100))

    local center_x=$((x + w / 2))

    case $direction in
        down)
            local start_y=$y
            local end_y=$((y + h))
            adb shell input swipe $center_x $start_y $center_x $end_y 500
            ;;
        up)
            local start_y=$((y + h))
            local end_y=$y
            adb shell input swipe $center_x $start_y $center_x $end_y 500
            ;;
    esac
}

# Zone de scroll: 10%, 30%, 20%, 40%
swipe_zone 10 30 20 40 up
```

### Exemple 3 : Automatisation complète
```bash
#!/bin/bash

# Script de test automatisé avec coordonnées de l'outil STF

# Coordonnées obtenues:
# - Bouton login: x=180, y=950 (18%, 95%)
# - Champ username: x=500, y=400 (50%, 40%)
# - Champ password: x=500, y=500 (50%, 50%)
# - Bouton submit: x=500, y=600 (50%, 60%)

tap_percent() {
    local resolution=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | head -1)
    local width=$(echo $resolution | cut -d'x' -f1)
    local height=$(echo $resolution | cut -d'x' -f2)
    local x=$((width * $1 / 100))
    local y=$((height * $2 / 100))
    adb shell input tap $x $y
}

input_text() {
    adb shell input text "$1"
}

echo "1. Clic sur le champ username"
tap_percent 50 40
sleep 1

echo "2. Saisie du username"
input_text "testuser"
sleep 1

echo "3. Clic sur le champ password"
tap_percent 50 50
sleep 1

echo "4. Saisie du password"
input_text "testpass123"
sleep 1

echo "5. Clic sur le bouton submit"
tap_percent 50 60
sleep 2

echo "Test terminé!"
```

---

## STF API

### Exemple 1 : Contrôle via l'API
```javascript
const STF_URL = 'http://stf.local';
const AUTH_TOKEN = 'your-auth-token';
const DEVICE_SERIAL = 'your-device-serial';

class STFController {
    constructor(url, token, serial) {
        this.url = url;
        this.token = token;
        this.serial = serial;
    }

    async tap(x_percent, y_percent) {
        // Coordonnées normalisées (0-1)
        const x = x_percent / 100;
        const y = y_percent / 100;

        const response = await fetch(
            `${this.url}/api/v1/user/devices/${this.serial}/input`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    type: 'touchDown',
                    contact: 0,
                    x: x,
                    y: y,
                    pressure: 0.5
                })
            }
        );

        // Touch up
        await fetch(
            `${this.url}/api/v1/user/devices/${this.serial}/input`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    type: 'touchUp',
                    contact: 0
                })
            }
        );
    }

    async swipe(x1_percent, y1_percent, x2_percent, y2_percent, duration = 500) {
        const x1 = x1_percent / 100;
        const y1 = y1_percent / 100;
        const x2 = x2_percent / 100;
        const y2 = y2_percent / 100;

        // Touch down
        await this.sendInput({ type: 'touchDown', contact: 0, x: x1, y: y1, pressure: 0.5 });

        // Move
        const steps = 10;
        for (let i = 1; i <= steps; i++) {
            const x = x1 + (x2 - x1) * i / steps;
            const y = y1 + (y2 - y1) * i / steps;
            await this.sendInput({ type: 'touchMove', contact: 0, x, y, pressure: 0.5 });
            await this.sleep(duration / steps);
        }

        // Touch up
        await this.sendInput({ type: 'touchUp', contact: 0 });
    }

    async sendInput(data) {
        return fetch(`${this.url}/api/v1/user/devices/${this.serial}/input`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Utilisation
const stf = new STFController(STF_URL, AUTH_TOKEN, DEVICE_SERIAL);

// Coordonnées de l'outil: 15%, 50%
await stf.tap(15, 50);

// Swipe de (50%, 80%) vers (50%, 20%)
await stf.swipe(50, 80, 50, 20, 500);
```

---

## Selenium + Appium

### Exemple avec Page Object Model
```python
from selenium.webdriver.common.by import By
from appium.webdriver.common.touch_action import TouchAction

class LoginPage:
    # Coordonnées obtenues avec l'outil STF
    USERNAME_FIELD = {'x_percent': 50, 'y_percent': 40}
    PASSWORD_FIELD = {'x_percent': 50, 'y_percent': 50}
    SUBMIT_BUTTON = {'x_percent': 50, 'y_percent': 60}

    def __init__(self, driver):
        self.driver = driver
        size = driver.get_window_size()
        self.width = size['width']
        self.height = size['height']

    def _tap_percent(self, coords):
        x = int(self.width * coords['x_percent'] / 100)
        y = int(self.height * coords['y_percent'] / 100)
        TouchAction(self.driver).tap(x=x, y=y).perform()

    def enter_username(self, username):
        self._tap_percent(self.USERNAME_FIELD)
        self.driver.find_element(By.CLASS_NAME, 'android.widget.EditText').send_keys(username)

    def enter_password(self, password):
        self._tap_percent(self.PASSWORD_FIELD)
        self.driver.find_element(By.CLASS_NAME, 'android.widget.EditText').send_keys(password)

    def submit(self):
        self._tap_percent(self.SUBMIT_BUTTON)

    def login(self, username, password):
        self.enter_username(username)
        self.enter_password(password)
        self.submit()

# Test
from appium import webdriver

driver = webdriver.Remote('http://localhost:4723/wd/hub', desired_caps)
login_page = LoginPage(driver)
login_page.login('testuser', 'testpass123')
```

---

## Cas d'usage avancés

### 1. Détection de changement d'UI
```python
import time
import hashlib
from appium import webdriver

def screenshot_zone_hash(driver, zone_percent):
    """Prend un screenshot d'une zone et retourne son hash"""
    # Prendre screenshot complet
    screenshot = driver.get_screenshot_as_png()

    # Calculer les coordonnées de la zone
    size = driver.get_window_size()
    from PIL import Image
    import io

    img = Image.open(io.BytesIO(screenshot))

    x = int(size['width'] * zone_percent['x'] / 100)
    y = int(size['height'] * zone_percent['y'] / 100)
    w = int(size['width'] * zone_percent['width'] / 100)
    h = int(size['height'] * zone_percent['height'] / 100)

    zone_img = img.crop((x, y, x + w, y + h))

    # Hash de l'image
    return hashlib.md5(zone_img.tobytes()).hexdigest()

# Surveiller une zone pour détecter des changements
zone = {'x': 10, 'y': 20, 'width': 80, 'height': 30}  # Zone du header
previous_hash = screenshot_zone_hash(driver, zone)

while True:
    time.sleep(1)
    current_hash = screenshot_zone_hash(driver, zone)
    if current_hash != previous_hash:
        print("Changement détecté dans la zone!")
        break
    previous_hash = current_hash
```

### 2. Test de scroll intelligent
```javascript
// Classe pour gérer le scroll dans des zones spécifiques
class SmartScroller {
    constructor(driver) {
        this.driver = driver;
    }

    async scrollUntilElementVisible(zonePercent, targetSelector, maxScrolls = 10) {
        const { width, height } = await this.driver.getWindowSize();

        const centerX = (zonePercent.x + zonePercent.width / 2) * width / 100;
        const startY = (zonePercent.y + zonePercent.height * 0.8) * height / 100;
        const endY = (zonePercent.y + zonePercent.height * 0.2) * height / 100;

        for (let i = 0; i < maxScrolls; i++) {
            try {
                const element = await this.driver.$(targetSelector);
                if (await element.isDisplayed()) {
                    return element;
                }
            } catch (e) {
                // Élément pas encore visible
            }

            // Scroll dans la zone
            await this.driver.touchPerform([
                { action: 'press', options: { x: centerX, y: startY } },
                { action: 'wait', options: { ms: 100 } },
                { action: 'moveTo', options: { x: centerX, y: endY } },
                { action: 'release' }
            ]);

            await this.driver.pause(500);
        }

        throw new Error('Element not found after ' + maxScrolls + ' scrolls');
    }
}

// Utilisation
const scroller = new SmartScroller(driver);

// Zone de scroll: 10%, 20%, 80%, 70%
const scrollZone = { x: 10, y: 20, width: 80, height: 70 };
const element = await scroller.scrollUntilElementVisible(scrollZone, '#target-element');
```

### 3. Générateur de Page Object automatique
```python
# Outil pour générer du code Page Object à partir des mesures

class PageObjectGenerator:
    def __init__(self):
        self.elements = []

    def add_element(self, name, x_percent, y_percent):
        """Ajoute un élément avec ses coordonnées"""
        self.elements.append({
            'name': name,
            'x_percent': x_percent,
            'y_percent': y_percent
        })

    def generate_class(self, class_name):
        """Génère le code Python pour la Page Object"""
        code = f"class {class_name}:\n"

        # Constantes
        for elem in self.elements:
            const_name = elem['name'].upper()
            code += f"    {const_name} = {{'x_percent': {elem['x_percent']}, 'y_percent': {elem['y_percent']}}}\n"

        code += "\n"
        code += "    def __init__(self, driver):\n"
        code += "        self.driver = driver\n"
        code += "        size = driver.get_window_size()\n"
        code += "        self.width = size['width']\n"
        code += "        self.height = size['height']\n"
        code += "\n"
        code += "    def _tap_percent(self, coords):\n"
        code += "        x = int(self.width * coords['x_percent'] / 100)\n"
        code += "        y = int(self.height * coords['y_percent'] / 100)\n"
        code += "        TouchAction(self.driver).tap(x=x, y=y).perform()\n"
        code += "\n"

        # Méthodes
        for elem in self.elements:
            method_name = f"tap_{elem['name']}"
            const_name = elem['name'].upper()
            code += f"    def {method_name}(self):\n"
            code += f"        self._tap_percent(self.{const_name})\n"
            code += "\n"

        return code

# Utilisation après mesure avec l'outil STF
gen = PageObjectGenerator()
gen.add_element('login_button', 50, 90)  # Mesures de l'outil
gen.add_element('username_field', 50, 40)
gen.add_element('password_field', 50, 50)

print(gen.generate_class('LoginPage'))
```

---

## 💡 Conseils

1. **Utilisez toujours les pourcentages** pour la portabilité entre résolutions
2. **Testez sur plusieurs résolutions** pour valider vos coordonnées
3. **Stockez les coordonnées dans des constantes** pour faciliter la maintenance
4. **Ajoutez des marges** si nécessaire (ex: `x_percent ± 2%`) pour gérer les variations
5. **Documentez vos mesures** avec des screenshots annotés

---

**Besoin de plus d'exemples ?** Consultez le README.md principal !
