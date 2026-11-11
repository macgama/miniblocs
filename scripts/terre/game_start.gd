class_name GameStart
extends RefCounted
## Choix fait sur le globe, transmis à la scène Terre.

## BAC_A_SABLE : carte perso, hors ligne.
## ENTRE_AMIS : carte partagée sur invitation, toujours accessible.
## MONDIALE : une seule carte de la Terre pour tous les joueurs.
enum Mode { BAC_A_SABLE, ENTRE_AMIS, MONDIALE }

## Côté de la région jouable autour du point de départ (mètres).
const REGION_SIZE := 10000.0

static var chosen := false
static var lat := 48.8584
static var lon := 2.2945
static var place_name := ""
static var mode: Mode = Mode.BAC_A_SABLE
