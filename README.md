# N3xtNVR

Client macOS natif (**Swift / SwiftUI**, **Apple Silicon arm64**) pour NVR type **Xiongmai / JFTech**, notamment **NBD80S16S** (16 voies) : protocole **NETSurveillance / DVRIP** sur **TCP 34567**, flux **RTSP**, découverte locale **UDP 34569**.

## Résumé des sources externes (directive projet)

Consultation effectuée **avant** de figer cette documentation :

| Source | Ce qui en ressort pour ce dépôt |
|--------|----------------------------------|
| **open.jftech.com** | Page « plateforme ouverte » (libellé générique côté constructeur). Pas de détail API exploitable dans le contenu récupéré automatiquement ; le projet ne repose pas sur un SDK propriétaire binaire. |
| **open.xmeye.net** (chemins `/`, `/en/index.php`) | **404** ou **timeout** au moment de la collecte — les fiches **NetSDK / PlaySDK** n’ont pas pu être indexées ici. À consulter manuellement pour alignement futur (fonctions natives constructeur). |
| **Implémentations communautaires** | Alignement sur la structure **DVRIP** documentée par reverse engineering : en-tête **20 octets** (`0xFF`, session, séquence, **msgId**, longueur), corps **JSON** terminé par **`\\n\\0`**. Références : **OpenIPC/python-dvr** (`dvrip.py`), **alexshpilkin/dvrip**, **sofia-netsurv/python-netsurv**. Port TCP par défaut **34567**, UDP **34568** dans certaines libs ; découverte LAN souvent **UDP 34569** (cf. **go2rtc**). |

## Objectif produit (MVP)

- **Matériel cible** : NVR **NBD80S16S** (carte Xiongmai / JFTech, 16 canaux).
- **Plateforme** : **macOS 15+**, **arm64 uniquement** (pas de dépendance Intel / Rosetta pour l’app).
- **Connexion** : IP locale, **hostname / DDNS**, ou **Cloud ID** (série XMeye) avec résolution DNS *best effort* ; port DVRIP **34567** ; utilisateur / mot de passe.
- **Dashboard** : grille **2×2** ou **4×4** (SwiftUI), liste des caméras avec titres DVRIP quand le firmware les expose (**ChannelTitle** / msg **1048**).
- **Vidéo** : lecture RTSP via **VLCKit** (paquet [VLCKitSPM](https://github.com/rursache/VLCKitSPM)), transport **RTSP/TCP** (`:rtsp-tcp`) — bien plus fiable qu’**AVPlayer** sur macOS pour les NVR Xiongmai. **FFmpeg** / **ffplay** restent utiles pour le diagnostic hors application.
- **PTZ** : commandes **OPPTZControl** (**1400**) sur la session TCP existante (**Network.framework** / `NWConnection`).

## Architecture (plan)

| Couche | Rôle |
|--------|------|
| **Models** | `NVRConnectionSettings` (hôte, Cloud ID, ports, gabarit RTSP), `AppSession` (état UI, session DVRIP, titres de voies). |
| **Services** | `DVRIPClient` (login **1000**, keep-alive **1006**, PTZ **1400**, titres **1048**), `NVRDiscoveryService` (UDP **34569**), `CloudIDResolver` (DNS). |
| **Views** | `LoginView`, `NVRDiscoveryView`, `MainDashboardView` (`NavigationSplitView`), `CameraGridView`, `RTSPPlayerCell` / `MacAVPlayerView`. |

Flux : **UI** → **AppSession** → **DVRIPClient** (file dédiée + async) ; **RTSP** construit depuis les paramètres et passé au lecteur **AVPlayer**.

## Prérequis

- macOS 15+
- [Xcode](https://developer.apple.com/xcode/) 16 (ou plus récent) avec les outils pour macOS
- Réseau joignable jusqu’au NVR (LAN, DDNS, ou résolution Cloud ID si DNS public disponible)

## Ouvrir et compiler

1. Ouvrir `N3xtNVR.xcodeproj`
2. Schéma **N3xtNVR**, destination **My Mac**
3. **⌘B** pour compiler, **⌘R** pour lancer

En ligne de commande (Xcode installé, pas seulement les CLT) :

```bash
xcodebuild -project N3xtNVR.xcodeproj -scheme N3xtNVR -configuration Debug build
```

Le fichier `project.pbxproj` peut être régénéré avec `python3 scripts/gen_pbx.py` après ajout de fichiers Swift.

**ARCHS = arm64** — pas de binaire Intel pour l’application.

## Dépendance Swift Package (vidéo)

Le projet référence **VLCKitSPM** (branche `master`) pour le décodage RTSP en direct. Xcode résout le paquet au premier build (`File > Packages > Resolve Package Versions` si besoin).

## Dépendances optionnelles (FFmpeg)

Pour diagnostiquer un flux en dehors de l’app :

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

Exemple :

```bash
ffplay -rtsp_transport tcp 'rtsp://USER:PASS@IP:554/cam/realmonitor?channel=1&subtype=0'
```

## Protocole (implémenté)

- **TCP 34567** : paquets DVRIP + JSON — voir `Services/DVRIPClient.swift`.
- **Découverte** : UDP **34569** (multicast / diffusion par sous-réseau) — `Services/NVRDiscoveryService.swift`.
- **RTSP** : gabarit avec `{user}` `{pass}` `{host}` `{port}` `{channel}` `{subtype}`.

## Cloud ID

Le **P2P propriétaire** XMeye complet n’est pas intégré. L’app tente une **résolution DNS** vers des hôtes courants (`*.cloudlinks.cn`, etc.) ; sinon utilisez **IP LAN** ou **DDNS**.

## Références

- [Plateforme ouverte JFTech](https://open.jftech.com/)
- [Portail développeur XMeye](https://open.xmeye.net/) (à parcourir manuellement si les pages SDK sont disponibles)
- [OpenIPC/python-dvr](https://github.com/OpenIPC/python-dvr) — structure DVRIP de référence
