# Imprimante 3D — Creality Ender-5 S1 sous Klipper

_Mis à jour le 16/11/2026._

| | |
|---|---|
| Machine | Creality Ender-5 S1, cartésienne, 220×220×280 mm |
| Extrudeur / hotend | Sprite direct drive d'origine, buse 0.4 mm |
| Palpeur | CR-Touch (clone BLTouch), offset X -12 / Y +27 |
| Plateau | plaque **G10** (époxy-verre) fixée, non amovible |
| Accéléromètre | RP2040 + ADXL345 « PIS » (`config/PIS.cfg`), support déporté loin de la buse ; `[include PIS.cfg]` commenté hors mesure |
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
| Input shaper | X mzv 64.8 Hz · Y mzv 46 Hz | `SHAPER_CALIBRATE` ×2 — 16/11/2026 (voir plus bas) |
| Accélération max | 5000 mm/s² (Klipper + profils Orca) | limite conseillée pour Y ≈ 6000 — 16/11/2026 |
| Pressure advance | 0.055 (générique) | **à étalonner** |
| Débit volumétrique max | 20.8 mm³/s mesuré → 17 dans le profil | test Orca *Max flowrate* 8→24 pas 0.5, défaut à 25.6 mm, buse 220 °C — 16/11/2026 |
| Température buse (PLA+) | 220 °C, 1re couche 225 | tour Orca 230→200 pas 5 : 215 le plus net, 220 retenu pour le débit (max mesuré à 220) ; ≤ 205 trop froid — 16/11/2026 |
| Flow, rétraction | — | **à étalonner** (tests intégrés d'OrcaSlicer) |

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

### Input shaper

Mesures du 16/11/2026, plateau à Z 80 au centre (accéléromètre sur un support déporté) :

- **X** : un seul pic net à 62–65 Hz, sans couplage avec les autres axes → mzv 64.8 Hz.
- **Y** : pic principal à 43 Hz, remonté à **46 Hz** après resserrage des roues excentriques.
  Pic **vertical** à ~90 Hz (2× le principal, surtout en Z) attribué au support de l'accéléromètre
  qui fait levier → ignoré ; Klipper proposait 2hump_ei 91 Hz à cause de ce pic, on garde mzv 46 Hz.
- Ancienne valeur (3hump_ei 65 Hz sur Y) incohérente avec ces mesures.
- **À refaire** avec la future tête custom (accéléromètre près de la buse, CR-Touch déplacé).

Procédure : décommenter `[include PIS.cfg]`, `FIRMWARE_RESTART`, `ACCELEROMETER_QUERY`, `G28`,
`SHAPER_CALIBRATE`, reporter dans `[input_shaper]`, recommenter l'include.
`AXES_MAP_CALIBRATION` n'existe pas dans cette version : l'`axes_map` a été vérifié en
enregistrant des mouvements X/Y (`ACCELEROMETER_MEASURE`).

## Macros utiles

| Macro | Rôle |
|---|---|
| `PRINT_START T_BED= T_EXTRUDER= SIZE=xmin_ymin_xmax_ymax` | chauffe, homing, maillage (`g10_<T_BED>` ou adaptatif), purge |
| `PRINT_END` | coupe les chauffes, retrait, parking |
| `MESH_PLATEAU T_BED= COUNT=` | grand maillage sauvegardé du plateau |
| `LOAD_FILAMENT` / `UNLOAD_FILAMENT` / `M600` | gestion du filament |

## Profils OrcaSlicer

Trois presets utilisateur, versionnés dans [`kubernetes/orcaslicer/profiles/`](../orcaslicer/profiles/)
et hérités des presets système Creality (seules les différences sont stockées) :

| Type | Nom | Hérite de | Points clés |
|---|---|---|---|
| Imprimante | `Ender-5 S1 Klipper` | `Creality Ender-5 S1 0.4 nozzle` | flavor Klipper, `PRINT_START`/`PRINT_END`, vignettes Mainsail, accel 5000, v 250, rétraction 0.8 mm @ 40 mm/s (provisoire) |
| Filament | `Ender PLA+` | `Creality Generic PLA` | 220 °C (1re couche 225), plateau 60 °C (tous types de plaque → maillage `g10_60`), débit max 17 mm³/s (mesuré 20.8 à 220 °C), flow 0.98 provisoire, PA géré par Klipper |
| Impression | `0.20mm Ender-5 S1 Klipper` | `0.20mm Standard @Creality Ender5S1` | vitesses reprises du profil Cura « parfait » (200 mm/s remplissage/parois int., 120 ext.), accel 5000 (3000 paroi ext./dessus, 500 1re couche), objets étiquetés (`EXCLUDE_OBJECT`) |

Installer / mettre à jour (Orca lit les presets au démarrage) :

```bash
U=/config/.config/OrcaSlicer/user/default
cd kubernetes/orcaslicer/profiles
for f in */*.json; do kubectl -n orcaslicer exec -i deploy/orcaslicer -- sh -c "cat > '$U/$f'" < "$f"; done
kubectl -n orcaslicer rollout restart deploy/orcaslicer
```

Après une modification dans l'interface (« Enregistrer »), recopier le fichier du volume vers le dépôt
(`kubectl -n orcaslicer exec deploy/orcaslicer -- cat "$U/<type>/<nom>.json"`).

Gcode de démarrage du profil imprimante :

```
PRINT_START T_BED=[bed_temperature_initial_layer_single] T_EXTRUDER=[nozzle_temperature_initial_layer] SIZE={first_layer_print_min[0]}_{first_layer_print_min[1]}_{first_layer_print_max[0]}_{first_layer_print_max[1]}
```

## Étalonnage du filament (menu *Calibration* d'OrcaSlicer)

Ordre à suivre, chaque test avec les trois presets ci-dessus sélectionnés ; reporter le résultat
dans le preset indiqué puis dans le tableau « Étalonnage » :

1. **Débit volumétrique max** (vers 220 °C) → `filament_max_volumetric_speed` (~80 % du point
   où ça casse) : fixe le plafond de vitesse.
2. **Température** (tour 230 → 190 °C) imprimée au débit visé → `nozzle_temperature`.
3. **Flow ratio** (passe 1 puis passe 2) → `filament_flow_ratio`.
4. **Pressure advance** (motif *Pattern*, PA 0 → 0.1, pas 0.005) à l'accélération finale →
   `pressure_advance` dans `printer.cfg` (`[extruder]`), le PA d'Orca reste désactivé.
5. **Rétraction** (tour 0 → 2 mm, pas 0.1) → `retraction_length` de l'imprimante.
6. Monter les vitesses du profil d'impression jusqu'au débit max, impression de contrôle.

Pendant les tests, baisser le temps de couche minimum du filament (`slow_down_layer_time`) pour que
les petites pièces ne soient pas ralenties.

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
