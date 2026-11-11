class_name GameStart
extends RefCounted
## Choix fait sur le globe, transmis à la scène Terre.

enum Mode { SOLO, ENSEMBLE }

## Côté de la région jouable autour du point de départ (mètres).
const REGION_SIZE := 10000.0

static var chosen := false
static var lat := 48.8584
static var lon := 2.2945
static var place_name := ""
static var mode: Mode = Mode.SOLO
