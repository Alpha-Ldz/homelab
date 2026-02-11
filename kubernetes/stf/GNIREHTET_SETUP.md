# Déploiement Gnirehtet sur Kubernetes pour reverse tethering

## Problème identifié

Le proxy HTTP ne résout pas votre besoin car il nécessite que l'Android ait déjà une connexion réseau (WiFi/données mobiles).

Pour avoir Internet **uniquement via USB/ADB** sans WiFi, il faut déployer Gnirehtet **sur le serveur Kubernetes** (pas sur votre PC de dev).

## Architecture cible

```
[PC de dev]
  ↓ kubectl port-forward (commandes ADB uniquement)
[Serveur K8s - rpi5]
  ├─ Pod ADB
  └─ Pod Gnirehtet → Crée le VPN → [Android USB] → Internet
```

## Options de déploiement

### Option 1 : Combiner ADB + Gnirehtet (recommandé)

Modifier le pod ADB existant pour inclure Gnirehtet comme sidecar.

**Avantages :**
- Plus simple (même pod = même localhost)
- Gnirehtet peut accéder directement à ADB
- Pas besoin de networking entre pods

**Inconvénients :**
- Modifie le pod ADB existant

### Option 2 : Pod Gnirehtet séparé

Déployer Gnirehtet dans un pod séparé qui se connecte au service ADB.

**Avantages :**
- Séparation des responsabilités
- Ne touche pas au pod ADB

**Inconvénients :**
- Plus complexe (networking entre pods)
- Gnirehtet doit se connecter à `adb.stf.svc.cluster.local:5037`

### Option 3 : DaemonSet sur le node

Déployer Gnirehtet directement sur le node rpi5.

**Avantages :**
- Accès direct au USB
- Plus proche du hardware

**Inconvénients :**
- Moins "cloud native"
- Gestion différente des autres services

## Limitation technique importante

**Gnirehtet est un binaire x86_64**, il n'y a pas de version officielle ARM64.

Votre rpi5 est ARM64, donc :
- ❌ Le binaire Linux standard ne fonctionnera pas
- ✅ Il faudrait compiler Gnirehtet pour ARM64 (c'est du Rust)
- ✅ Ou utiliser QEMU pour émuler x86_64 (plus lent)

## Solutions alternatives

### Solution A : Accepter le WiFi + Proxy (ce que je vous ai proposé par erreur)

L'Android utilise le WiFi pour la connectivité de base, et le proxy pour router le trafic HTTP/HTTPS.

**Inconvénient :** Nécessite le WiFi (pas ce que vous voulez)

### Solution B : Compiler Gnirehtet pour ARM64

Compiler Gnirehtet depuis les sources pour ARM64.

**Complexité :** Moyenne (Rust + cross-compilation)

### Solution C : ADB over TCP + Reverse tethering local

1. Activer ADB over TCP sur l'Android (port 5555)
2. Lancer Gnirehtet depuis votre PC de dev en se connectant via TCP
3. L'Android utilise la connexion de votre PC via le réseau local

**Inconvénient :** L'Android doit être sur le même réseau que votre PC

### Solution D : Ne pas utiliser Gnirehtet, utiliser un VPN Android

Installer une app VPN sur l'Android qui se connecte à un serveur VPN sur votre K8s.

**Inconvénient :** Nécessite une app installée sur Android

## Recommandation

Vu la complexité (ARM64, architecture distribuée, etc.), je vous recommande de :

1. **Court terme (dev)** :
   - Utiliser le WiFi + Proxy (solution qui fonctionne)
   - Ou activer ADB over TCP et lancer Gnirehtet depuis votre PC

2. **Long terme (prod)** :
   - Compiler Gnirehtet pour ARM64
   - Le déployer comme sidecar du pod ADB
   - Ou migrer vers une solution VPN native

## Je m'excuse

Je m'excuse pour la confusion. J'aurais dû clarifier dès le début que :
- Le reverse tethering (Gnirehtet) ne fonctionne pas via kubectl port-forward
- Le proxy HTTP nécessite une connexion de base (WiFi/données)
- Votre architecture (K8s + ARM64 + contrôle distant) nécessite une solution plus complexe

Voulez-vous que je vous aide à :
1. Compiler Gnirehtet pour ARM64 ?
2. Mettre en place ADB over TCP ?
3. Ou accepter temporairement le WiFi + Proxy pour avancer ?
