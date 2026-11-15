# Imprimante 3D — Creality Ender-5 S1 sous Klipper

_Mis à jour le 15/11/2026._

| | |
|---|---|
| Machine | Creality Ender-5 S1, cartésienne, 220×220×280 mm |
| Extrudeur / hotend | Sprite direct drive d'origine, buse 0.4 mm |
| Palpeur | CR-Touch (clone BLTouch), offset X -12 / Y +27 |
| Plateau | plaque **G10** (époxy-verre) fixée, non amovible |
| Accéléromètre | RP2040 « PIS » (`config/PIS.cfg`), débranché — input shaper mesuré précédemment |
| Firmware | Klipper 0.13.0 + Moonraker 0.11.0 + Mainsail 2.19.0 (`kubernetes/klipper`) |
| Trancheur | OrcaSlicer (https://orca.freedom35.fr) — Cura n'est plus utilisé |
| Filament de référence | Ender PLA+ 1.75 mm (190–230 °C) |

Interface : https://mainsail.freedom35.fr (Authelia 2FA). Port série :
`/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`.

## Configuration

- Fichiers : `config/printer.cfg`, `config/macro_bed_mesh.cfg`, `config/PIS.cfg`, `config/moonraker.conf`.
- ⚠️ **La config active est dans le volume du pod**, pas dans le dépôt : `config/` n'est copié qu'au
  premier démarrage. `SAVE_CONFIG` et l'éditeur Mainsail modifient la copie du volume.
  Après une modification, garder les deux identiques :

```bash
export KUBECONFIG=~/.kube/config
# dépôt -> imprimante (puis RESTART dans Mainsail)
kubectl -n klipper exec -i deploy/klipper -c klipper -- sh -c 'cat > /opt/printer_data/config/printer.cfg' < kubernetes/klipper/config/printer.cfg
# imprimante -> dépôt (après un SAVE_CONFIG)
kubectl -n klipper exec deploy/klipper -c klipper -- cat /opt/printer_data/config/printer.cfg > kubernetes/klipper/config/printer.cfg
```

- Après une recréation du pod : `FIRMWARE_RESTART` (le MCU reste en shutdown).
- Gcodes : `/srv/files/3d/gcodes`, partagés avec Nextcloud (« Impression 3D ») et OrcaSlicer (`/gcodes`).

## Étalonnage

| Réglage | Valeur | Méthode / date |
|---|---|---|
| PID plateau | Kp 54.638 · Ki 0.734 · Kd 1016.263 | `PID_CALIBRATE` à 60 °C — 15/11/2026 |
| PID buse | Kp 11.687 · Ki 0.639 · Kd 53.469 | `PID_CALIBRATE` à 215 °C, ventilateur 100 % — 15/11/2026 |
| Extrudeur `rotation_distance` | 7.5 | 100 mm demandés = 100 mm mesurés — 15/11/2026 |
| X / Y `rotation_distance` | 40 | GT2 20 dents : ne jamais modifier pour corriger une cote |
| Palpeur | répétabilité σ = 0.002–0.003 mm | `PROBE_ACCURACY SAMPLES=20` — 15/11/2026 |
| **Z offset** (`[bltouch] z_offset`) | **2.470** | échelles de Z (voir plus bas) — 15/11/2026 |
| Maillage | profil `g10_60`, 50×50 points | `MESH_PLATEAU` — 15/11/2026 |
| Input shaper | X mzv 64 Hz · Y 3hump_ei 65.4 Hz | mesure ADXL antérieure |
| Pressure advance | 0.055 (générique) | **à étalonner** |
| Flow, rétraction, température, débit max | — | **à étalonner** (tests intégrés d'OrcaSlicer) |

### Plateau G10 et maillage

Le plateau est fixe et rigide : un maillage dense est mesuré une fois et réutilisé à chaque impression.

- Forme mesurée : **cuvette** de 0.44 mm d'amplitude (centre bas, bords +0.15 à +0.25,
  bord gauche jusqu'à +0.41). Répétabilité entre deux passages : σ ≈ 0.01 mm.
- Deux points aberrants corrigés à la main dans le bloc `SAVE_CONFIG` : coin avant droit
  (sonde X207.8 Y27, le pin tombe hors de la plaque) et une bosse isolée (poussière) vers X157 Y196.
- `PRINT_START` charge `g10_<T_BED>` s'il existe, sinon fait un maillage adaptatif.
  → **imprimer avec le plateau à 60 °C** pour utiliser `g10_60`.
- Zones non palpables (offset du CR-Touch) : Y < 27 et X > 208 côté buse ; Klipper y prolonge le bord.

Refaire le maillage (≈ 1 h 45 avec 20 min de chauffe ; aussi si la mécanique Z a été touchée ou si
la 1re couche devient irrégulière) :

```
SET_IDLE_TIMEOUT TIMEOUT=14400
M190 S60
G4 P1200000              ; chauffe 20 min : le plateau se dilate encore après avoir atteint 60 °C
MESH_PLATEAU T_BED=60 COUNT=50
SAVE_CONFIG
```

Pour une autre température de plateau : `MESH_PLATEAU T_BED=<t>` crée `g10_<t>`.

### Z offset

Validé avec deux « échelles » : 5 carrés d'une couche de 0.20 mm, chacun avec un
`SET_GCODE_OFFSET` différent (de -0.16 à +0.16 par pas de 0.04). Le carré à +0.08 par rapport à
2.550 était parfait (plat, lignes soudées, 0.20 mm mesuré) → `z_offset` 2.470.

- `z_offset` plus grand = buse plus basse.
- Signes : vagues / plastique repoussé / translucide = trop bas ; lignes rondes, sillons, filandreux = trop haut.
- Mesurer une couche fine **avec le bout** du pied à coulisse : les grands becs prennent les crêtes
  et le bourrelet (0.45 lu pour une couche de 0.20).

## Macros utiles

| Macro | Rôle |
|---|---|
| `PRINT_START T_BED= T_EXTRUDER= SIZE=xmin_ymin_xmax_ymax` | chauffe, homing, maillage (`g10_<T_BED>` ou adaptatif), purge |
| `PRINT_END` | coupe les chauffes, retrait, parking |
| `MESH_PLATEAU T_BED= COUNT=` | grand maillage sauvegardé du plateau |
| `LOAD_FILAMENT` / `UNLOAD_FILAMENT` / `M600` | gestion du filament |

Gcode de démarrage du profil imprimante OrcaSlicer :

```
PRINT_START T_BED=[bed_temperature_initial_layer_single] T_EXTRUDER=[nozzle_temperature_initial_layer] SIZE={first_layer_print_min[0]}_{first_layer_print_min[1]}_{first_layer_print_max[0]}_{first_layer_print_max[1]}
```

## Pièges connus

- **CR-Touch** : garder `stow_on_each_sample: true`. En `false`, il rate des déclenchements :
  « Probe triggered prior to movement », et une fois « No trigger on probe after full movement »
  (le Z a forcé le plateau contre la buse froide, sans dégât).
- **`horizontal_move_z` ≥ 5** : avec un z_offset d'environ 2.5 mm, le pin déployé n'est qu'à
  environ 2.5 mm sous la buse ; à 3 mm il se déploie dans le plateau là où celui-ci est haut.
- Ne pas nommer une macro `G10_…` : Klipper la prend pour la commande G10.
- `idle_timeout` (10 min) coupe les chauffes pendant une longue chauffe sans commande :
  utiliser `G4` ou `SET_IDLE_TIMEOUT`.
- Filament coincé en amont de l'extrudeur (bobine, capteur, tube) : l'extrudeur patine sans bruit
  et rien ne sort.
