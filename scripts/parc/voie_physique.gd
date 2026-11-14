class_name VoiePhysique
extends RefCounted
## Simulation d'un tour d'attraction sur voie : vitesse (énergie, frottements,
## chaîne, lanceur, freins, courant de l'eau), forces ressenties (G vertical et
## latéral), relevé automatique des virages, puis les notes (excitation,
## intensité, nausée) et ce que l'attraction vaut pour le parc.
##
## Ordres de grandeur : grands-huit européens (chaîne ≈ 3,5 m/s, 4 à 5 G au
## plus en bas d'une chute, −1 G au plus en apesanteur, 1,8 G latéraux au plus).

const G := 9.81
## Vitesse de sortie de gare (m/s) et vitesse en gare (freins de gare).
const V_GARE := 1.6
const V_FREINS := 6.0
const V_LANCEUR := 28.0
const A_LANCEUR := 11.0
## Temps d'arrêt en gare (s) : descendre, monter, vérifier les harnais.
const ARRET_GARE := 40.0
## Seuils d'alerte.
const G_MAX := 5.0
const G_MIN := -1.5
const G_LAT := 2.0


## Calcule tout. `tr` vient de VoiePieces.trace(). Ajoute au tracé "U" et "R"
## relevés (roulis compris) et renvoie les résultats.
static func simule(design: Dictionary, tr: Dictionary) -> Dictionary:
	var fam := VoiePieces.famille(String(design.get("famille", "acier")))
	var P: PackedVector3Array = tr.P
	var n := P.size()
	var res := {"ok": true, "erreurs": [], "avert": [], "v": PackedFloat32Array(), "t": PackedFloat32Array(),
		"s": PackedFloat32Array(), "gv": PackedFloat32Array(), "gl": PackedFloat32Array(), "Ub": PackedVector3Array(), "Rb": PackedVector3Array()}
	if n < 3:
		res.ok = false
		return res
	var mu := float(fam.mu)
	var air := float(fam.air)
	var courant := float(fam.get("courant", 0.0))
	var chaine := float(fam.chaine)
	var genre := String(fam.genre)
	var v := V_GARE
	var t := 0.0
	var s := 0.0
	var cale := -1
	var vv := PackedFloat32Array()
	var tt := PackedFloat32Array()
	var ss := PackedFloat32Array()
	vv.resize(n)
	tt.resize(n)
	ss.resize(n)
	vv[0] = v
	var specials: Array = tr.special
	var chaines: PackedByteArray = tr.chaine
	var hauteur_gare := float(fam.h_gare)
	if genre == "glisse":
		v = 1.0
		vv[0] = v
	for i in range(1, n):
		var ds := P[i].distance_to(P[i - 1])
		var dh := P[i].y - P[i - 1].y
		var v2 := v * v - 2.0 * G * dh - 2.0 * (mu * G + air * v * v) * ds
		var sp := String(specials[i])
		var vn := sqrt(maxf(v2, 0.0))
		if chaines[i] == 1 and vn < chaine:
			vn = chaine
		match sp:
			"gare":
				vn = V_GARE
			"freins":
				vn = minf(vn, V_FREINS)
			"lanceur":
				if vn < V_LANCEUR:
					vn = minf(sqrt(vn * vn + 2.0 * A_LANCEUR * ds), V_LANCEUR)
			"eclabousse":
				vn = maxf(vn * 0.93, courant)
			"arrivee":
				vn = maxf(vn * 0.85, 0.8)
		# Raccord vers la gare : pneus motorisés (au moins 2 m/s), comme les vraies gares.
		if sp == "raccord" and vn < 2.0:
			vn = 2.0
		if genre == "eau" or genre == "glisse":
			var pente := rad_to_deg(asin(clampf((tr.F as PackedVector3Array)[i].y, -1.0, 1.0)))
			if absf(pente) < 8.0 and vn < courant:
				vn = courant
		if vn < 0.25 and cale < 0:
			cale = i
		if vn < 0.25:
			vn = 1.0  # on pousse le train pour finir les calculs
		var vm := (v + vn) / 2.0
		t += ds / maxf(vm, 0.2)
		s += ds
		v = vn
		vv[i] = v
		tt[i] = t
		ss[i] = s
	res.v = vv
	res.t = tt
	res.s = ss
	# Forces ressenties et relevé automatique.
	var F: PackedVector3Array = tr.F
	var U0: PackedVector3Array = tr.U
	var R0: PackedVector3Array = tr.R
	var rolls: PackedFloat32Array = tr.roll
	var releve: PackedByteArray = tr.releve
	var bmax := deg_to_rad(float(fam.releve_max))
	var auto := PackedFloat32Array()
	auto.resize(n)
	var fel: Array[Vector3] = []
	fel.resize(n)
	for i in n:
		var a := maxi(i - 2, 0)
		var b := mini(i + 2, n - 1)
		var k := Vector3.ZERO
		if b - a >= 2:
			var m := (a + b) / 2
			var l1 := maxf(P[m].distance_to(P[a]), 0.01)
			var l2 := maxf(P[b].distance_to(P[m]), 0.01)
			var t1 := (P[m] - P[a]) / l1
			var t2 := (P[b] - P[m]) / l2
			k = (t2 - t1) / ((l1 + l2) / 2.0)
		var f := k * vv[i] * vv[i] + Vector3(0, G, 0)
		fel[i] = f
		if releve[i] == 1 and bmax > 0.0:
			auto[i] = clampf(atan2(f.dot(R0[i]), maxf(f.dot(U0[i]), 0.5)), -bmax, bmax)
	# Lissage du relevé sur ±6 m.
	var lisse := PackedFloat32Array()
	lisse.resize(n)
	var w := 12
	for i in n:
		var acc := 0.0
		var c := 0
		for j in range(maxi(0, i - w), mini(n, i + w + 1)):
			acc += auto[j]
			c += 1
		lisse[i] = acc / c
	var Ub := PackedVector3Array()
	var Rb := PackedVector3Array()
	var gv := PackedFloat32Array()
	var gl := PackedFloat32Array()
	var suspendu := bool(fam.get("suspendu", false))
	for i in n:
		var beta := rolls[i] + lisse[i]
		var u := U0[i] * cos(beta) + R0[i] * sin(beta)
		var r := R0[i] * cos(beta) - U0[i] * sin(beta)
		Ub.append(u)
		Rb.append(r)
		var f: Vector3 = fel[i]
		if suspendu:
			# Les sièges se balancent : le latéral passe presque tout en vertical.
			gv.append(f.length() / G * signf(f.dot(u)) if f.dot(u) != 0.0 else 0.0)
			gl.append(f.dot(r) / G * 0.35)
		else:
			gv.append(f.dot(u) / G)
			gl.append(f.dot(r) / G)
	res.Ub = Ub
	res.Rb = Rb
	# Lissage des G (les capteurs des vrais trains aussi lissent).
	res.gv = _moyenne(gv, 4)
	res.gl = _moyenne(gl, 4)
	_stats(design, tr, res, fam, cale, hauteur_gare)
	return res


static func _moyenne(a: PackedFloat32Array, w: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		var acc := 0.0
		var c := 0
		for j in range(maxi(0, i - w), mini(a.size(), i + w + 1)):
			acc += a[j]
			c += 1
		out[i] = acc / c
	return out


static func _stats(design: Dictionary, tr: Dictionary, res: Dictionary, fam: Dictionary, cale: int, h_gare: float) -> void:
	var P: PackedVector3Array = tr.P
	var n := P.size()
	var vv: PackedFloat32Array = res.v
	var gv: PackedFloat32Array = res.gv
	var gl: PackedFloat32Array = res.gl
	var pieces: Array = design.get("pieces", [])
	var vmax := 0.0
	var ymax := -INF
	var ymin := INF
	var gvmax := -INF
	var gvmin := INF
	var glmax := 0.0
	var air_t := 0.0
	var chute := 0.0
	var haut := P[0].y
	for i in n:
		vmax = maxf(vmax, vv[i])
		ymax = maxf(ymax, P[i].y)
		ymin = minf(ymin, P[i].y)
		if String(tr.special[i]) != "gare":
			gvmax = maxf(gvmax, gv[i])
			gvmin = minf(gvmin, gv[i])
			glmax = maxf(glmax, absf(gl[i]))
		if i > 0:
			if P[i].y > P[i - 1].y + 0.01:
				haut = maxf(haut, P[i].y) if P[i - 1].y >= haut - 0.5 else P[i].y
			chute = maxf(chute, haut - P[i].y)
			if gv[i] < 0.25 and vv[i] > 4.0:
				air_t += ((res.t as PackedFloat32Array)[i] - (res.t as PackedFloat32Array)[i - 1])
	var inv := 0
	var tunnels := 0
	var eclab := 0
	var rapides := 0
	var tours := 0
	var lanceurs := 0
	var chaine_m := 0.0
	for e in pieces:
		var d := VoiePieces.piece(String(e.p))
		inv += int(d.get("inv", 0))
		match String(d.get("special", "")):
			"tunnel": tunnels += 1
			"eclabousse": eclab += 1
			"rapides": rapides += 1
			"tourbillon": tours += 1
			"lanceur": lanceurs += 1
		if bool(e.get("chaine", false)):
			chaine_m += float(d.get("L", 8.0))
	var longueur := (res.s as PackedFloat32Array)[n - 1]
	var duree := (res.t as PackedFloat32Array)[n - 1]
	if gvmax == -INF:
		gvmax = 1.0
		gvmin = 1.0
	res["longueur"] = longueur
	res["duree"] = duree
	res["v_max"] = vmax
	res["h_max"] = ymax
	res["h_min"] = ymin
	res["chute"] = chute
	res["gv_max"] = gvmax
	res["gv_min"] = gvmin
	res["gl_max"] = glmax
	res["airtime"] = air_t
	res["inversions"] = inv
	res["tunnels"] = tunnels
	res["chaine_m"] = chaine_m
	var genre := String(fam.genre)
	var erreurs: Array = res.erreurs
	var avert: Array = res.avert
	if cale >= 0:
		var p := int((tr.piece as PackedInt32Array)[cale])
		var ou := "dans la gare" if p < 0 else ("dans le raccord" if p >= pieces.size() else "pièce %d (%s)" % [p + 1, VoiePieces.piece(String(pieces[p].p)).get("nom", "?")])
		erreurs.append("Le %s cale %s : il manque de l'élan. Ajoute une chaîne%s ou baisse la bosse." % ["bateau" if genre == "eau" else ("baigneur" if genre == "glisse" else "train"), ou, " (tapis)" if genre == "eau" else ""])
	if not bool(tr.ferme):
		erreurs.append("Le parcours n'arrive pas au bassin d'arrivée." if bool(tr.ouvert) else "Le circuit n'est pas bouclé : reviens à la gare ou clique sur « Boucler ».")
	if gvmax > G_MAX:
		avert.append("%.1f G en bas d'une descente : les visiteurs voient trouble. Adoucis la fin de descente." % gvmax)
	if gvmin < G_MIN:
		avert.append("%.1f G au sommet : les visiteurs décollent de leur siège. Arrondis la bosse." % gvmin)
	if glmax > G_LAT:
		avert.append("%.1f G latéraux : virage trop serré pour la vitesse. Prends un grand virage." % glmax)
	if vv[n - 1] > 9.0 and not bool(fam.get("ouvert", false)):
		avert.append("Arrivée en gare à %d km/h : ajoute des freins avant la gare." % roundi(vv[n - 1] * 3.6))
	if ymin < -1.5 and genre != "eau":
		avert.append("Une partie du tracé passe sous la gare : vérifie qu'elle ne rentre pas dans le sol (sinon c'est un tunnel).")
	res.ok = erreurs.is_empty()
	# Notes de 0 à 10.
	var kmh := vmax * 3.6
	var duree_min := duree / 60.0
	var exc := 0.8 + kmh / 22.0 + (ymax - h_gare) / 22.0 + chute / 18.0 + inv * 0.75 + air_t * 0.35 + minf(duree_min, 2.5) * 0.7 \
		+ tunnels * 0.35 + eclab * 1.2 + rapides * 0.6 + tours * 0.4 + lanceurs * 0.8
	var inten := kmh / 30.0 + maxf(gvmax - 1.5, 0.0) * 0.9 + maxf(-gvmin, 0.0) * 1.2 + glmax * 1.3 + inv * 0.35 + lanceurs * 0.6
	var nau := glmax * 1.8 + inv * 0.55 + rapides * 0.9 + tours * 1.4 + maxf(gvmax - 3.0, 0.0) * 0.8
	if genre == "eau":
		exc += 0.6
		inten *= 0.7
	if genre == "glisse":
		exc += 0.3
	# Trop intense : l'excitation baisse (on ne s'amuse plus, on survit).
	if inten > 8.5:
		exc -= (inten - 8.5) * 0.8
	res["exc"] = clampf(exc, 0.0, 10.0)
	res["int"] = clampf(inten, 0.0, 10.0)
	res["nau"] = clampf(nau, 0.0, 10.0)


## Ce que l'attraction vaut pour le parc (champ "parc" du catalogue) et son prix.
static func spec_parc(design: Dictionary, res: Dictionary) -> Dictionary:
	var fam := VoiePieces.famille(String(design.get("famille", "acier")))
	var voitures := int(design.get("voitures", fam.voitures))
	var trains := int(design.get("trains", fam.get("trains", 1)))
	var places := int(fam.places) * voitures
	var duree := float(res.get("duree", 60.0))
	var arret := ARRET_GARE if String(fam.genre) != "glisse" else 25.0
	var exc := float(res.get("exc", 3.0))
	var inten := float(res.get("int", 3.0))
	return {"role": "attraction", "cap": places * maxi(trains, 1), "cycle": maxf((duree + arret) / 60.0, 1.0),
		"exc": snappedf(exc, 0.1), "int": snappedf(inten, 0.1), "nau": snappedf(float(res.get("nau", 0.0)), 0.1),
		"attrait": snappedf(1.0 + exc * 0.85, 0.1), "usure": snappedf(0.03 + inten * 0.006 + float(res.get("longueur", 300.0)) / 12000.0, 0.001),
		"voie": true}


static func prix(design: Dictionary, res: Dictionary) -> int:
	var fam := VoiePieces.famille(String(design.get("famille", "acier")))
	var longueur := float(res.get("longueur", 0.0))
	var haut := maxf(float(res.get("h_max", 0.0)) - float(fam.h_gare), 0.0)
	var p := float(fam.gare_prix) + longueur * float(fam.m_prix) * (1.0 + haut / 60.0)
	p += int(res.get("inversions", 0)) * 250_000
	for e in design.get("pieces", []):
		if String(VoiePieces.piece(String(e.p)).get("special", "")) == "lanceur":
			p += 1_500_000
	var trains := int(design.get("trains", fam.get("trains", 1)))
	var voitures := int(design.get("voitures", fam.voitures))
	p += trains * voitures * 40_000
	return int(roundf(p / 10_000.0) * 10_000.0)


static func emplois(design: Dictionary) -> Array:
	var fam := VoiePieces.famille(String(design.get("famille", "acier")))
	var gros := float(fam.gare_prix) >= 700_000
	return [["operateur_attraction", 3 if gros else 2], ["technicien_attraction", 1 if gros else 0]]


## Note sur 10 en mots.
static func mot(x: float) -> String:
	if x < 2.0:
		return "très faible"
	if x < 4.0:
		return "faible"
	if x < 6.0:
		return "moyenne"
	if x < 8.0:
		return "forte"
	return "très forte"
