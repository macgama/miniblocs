class_name GestionAuto
extends RefCounted
## Gestion d'une ville par quelqu'un d'autre que le joueur : le maire élu
## quand le joueur a perdu la mairie (réglage « mairie perdue »), et plus tard
## le pilote automatique demandé par le joueur.
##
## Règles du budget (une fois par semaine de jeu) :
##   - chaque liste vise ses impôts (POLITIQUES) ;
##   - caisse dans le rouge ou mois déficitaire : impôts relevés (jusqu'à 180 %) ;
##   - plus de 6 mois de dépenses en caisse et mois positif : impôts baissés ;
##   - les taux bougent de 5 points par semaine au plus ;
##   - entretien des voies au niveau de la liste, réparations automatiques ;
##   - emprunt de 500 k€ seulement si la caisse est dans le rouge et la dette
##     sous un an de recettes ; remboursement anticipé si la caisse le permet.

## Impôts et entretien visés par chaque tendance (Elections.TENDANCES).
const POLITIQUES := {
	"contribuables": {"nom": "impôts bas, dépenses serrées", "taux": 0.8, "entretien": 0.9},
	"securite": {"nom": "impôts stables, ordre et entretien", "taux": 1.0, "entretien": 1.1},
	"ecologie": {"nom": "impôts un peu plus hauts, ville soignée", "taux": 1.1, "entretien": 1.1},
	"solidarite": {"nom": "impôts plus hauts, services pour tous", "taux": 1.2, "entretien": 1.0},
	"equilibre": {"nom": "budget à l'équilibre", "taux": 1.0, "entretien": 1.0},
}
const TAUX_MAX_IA := 1.8
const PAS := 0.05
const JOURS_ENTRE := 7
const EMPRUNT_IA := 500_000


static func politique(tendance: String) -> Dictionary:
	return POLITIQUES.get(tendance, POLITIQUES.equilibre)


## Exécute f() avec l'état budgétaire et la caisse de la ville vid chargés.
static func dans_ville(vid: int, f: Callable) -> void:
	var b := BudgetCommunal.instance
	var p := Pays.instance
	if b == null or p == null or vid < 0:
		return
	var sel := b.cle
	b.selectionner(vid)
	var prev := p.entrer(vid)
	b._ia = true
	f.call(b)
	b._ia = false
	p.sortir(prev)
	b.selectionner(sel)
	b.changed.emit()


## Le nouveau maire applique tout de suite son programme.
static func appliquer_politique(vid: int, tendance: String) -> void:
	var pol := politique(tendance)
	dans_ville(vid, func(b: BudgetCommunal) -> void:
		for k in b.taux:
			b.set_taux(k, float(pol.taux))
		for v in b.entretien:
			b.set_entretien(v, "taux", float(pol.entretien))
			b.set_entretien(v, "auto", true))


## Gestion de la semaine par le maire élu (appelé chaque jour par Avis).
static func gerer_maire(vid: int, maire: Dictionary, jour: int) -> void:
	if posmod(jour + vid, JOURS_ENTRE) != 0:
		return
	gerer_budget(vid, String(maire.get("tendance", "equilibre")))
	# Arrêtés des quartiers selon son programme (un changement par semaine).
	if Quartiers.instance != null:
		Quartiers.instance.gerer_conseil(vid, String(maire.get("tendance", "")))


static func gerer_budget(vid: int, tendance: String) -> void:
	var pol := politique(tendance)
	dans_ville(vid, func(b: BudgetCommunal) -> void: _semaine(b, pol))


static func _semaine(b: BudgetCommunal, pol: Dictionary) -> void:
	var bilan: Dictionary = b.dernier if not b.dernier.is_empty() else b.bilan_mensuel()
	var caisse := float(b.caisse())
	var solde := float(bilan.get("solde", 0.0))
	var dep := maxf(1.0, float(bilan.get("total_depenses", 0.0)))
	var cible := float(pol.taux)
	if caisse < 0.0 or solde < 0.0:
		cible = minf(TAUX_MAX_IA, cible + 0.3 + (0.3 if caisse < 0.0 else 0.0))
	elif caisse > dep * 6.0 and solde > 0.0:
		cible = maxf(0.5, cible - 0.1)
	for k in b.taux:
		var t := float(b.taux[k])
		b.set_taux(k, t + clampf(cible - t, -PAS, PAS))
	for v in b.entretien:
		var e := float(b.entretien[v].taux)
		b.set_entretien(v, "taux", e + clampf(float(pol.entretien) - e, -PAS * 2.0, PAS * 2.0))
		b.set_entretien(v, "auto", true)
	if caisse < 0.0 and b.dette() < maxf(b.recettes_annuelles(), 2_000_000.0) and b.refus_emprunt(EMPRUNT_IA, 10) == "":
		b.emprunter(EMPRUNT_IA, 10)
	elif not b.emprunts.is_empty():
		var plus_petit: Dictionary = b.emprunts[0]
		for e in b.emprunts:
			if float(e.restant) < float(plus_petit.restant):
				plus_petit = e
		if caisse > float(plus_petit.restant) * 3.0 + dep * 3.0:
			b.rembourser(int(plus_petit.id))
