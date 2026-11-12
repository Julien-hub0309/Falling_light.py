class_name Competences
extends RefCounted
## Arbre de craft des classes (README « arbre de craft des classes »). 3 niveaux par classe :
##   niveau 1 PASSIF (dès le départ), niveau 2 ACTIF (touche T), niveau 3 ULTIME (touche Y).
## Déblocage : par les loots ramassés (rouge + orange + bleu + vert) : niveau 2 à 6, niveau 3 à 15.
##
##   ASSAUT  : Sprint amélioré (+10 % vitesse, rechargement rapide après un kill)
##             -> Grappin éclair (recharge 1 s, portée 70 m)  -> SURCHAUFFE (10 s)
##   BRECHE  : Armure lourde (-40 % dégâts explosifs, pas de pénalité de vitesse)
##             -> CHARGE EXPLOSIVE (détruit les structures, sonne les ennemis) -> LANCE-ROQUETTES
##   SNIPER  : (Recon) Silencieux (tes tirs n'alertent pas et n'apparaissent pas sur la mini-carte)
##             -> SCAN RADAR (6 s, 70 m) -> CAMOUFLAGE (8 s)
##   TACTIC  : Sacoche (un pack de soin / d'armure toutes les 45 s)
##             -> BOUCLIER PORTATIF (300 PV, 25 s) -> RANIMATION (revient à 60 % de PV quand tu meurs)

const NIVEAU2 := 6
const NIVEAU3 := 15
const CD_ACTIF := {"BRECHE": 18.0, "SNIPER": 25.0, "TACTIC": 20.0}
const CD_ULTIME := {"ASSAUT": 60.0, "BRECHE": 70.0, "SNIPER": 60.0, "TACTIC": 90.0}
const SURCHAUFFE_DUREE := 10.0
const ROQUETTES_DUREE := 25.0
const RADAR_DUREE := 6.0
const RADAR_RAYON := 70.0
const CAMO_DUREE := 8.0


static func neuf() -> Dictionary:
	return {"cd_actif": 0.0, "cd_ultime": 0.0, "ult_t": 0.0, "radar_t": 0.0, "camo_t": 0.0,
		"sacoche": 30.0, "niv_annonce": 1}


static func cle(p: Pilote) -> String:
	return p.classe.get("nom", "")


static func niveau(p: Pilote) -> int:
	var d: Dictionary = p.craft
	var total: int = d["rouge"] + d["orange"] + d["bleu"] + d["vert"]
	if total >= NIVEAU3:
		return 3
	if total >= NIVEAU2:
		return 2
	return 1


static func nom_actif(p: Pilote) -> String:
	match cle(p):
		"ASSAUT": return "Grappin éclair"
		"BRECHE": return "Charge explosive"
		"SNIPER": return "Scan radar"
		"TACTIC": return "Bouclier portatif"
	return ""


static func nom_ultime(p: Pilote) -> String:
	match cle(p):
		"ASSAUT": return "Surchauffe"
		"BRECHE": return "Lance-roquettes"
		"SNIPER": return "Camouflage"
		"TACTIC": return "Ranimation"
	return ""


# ------------------------------------------------------------------ passifs ----
static func mult_vitesse(p: Pilote) -> float:
	match cle(p):
		"ASSAUT": return 1.1                       # sprint amélioré
		"BRECHE": return 1.0 / 0.92                # armes lourdes sans pénalité de vitesse
	return 1.0


static func reduc_explosif(p: Pilote) -> float:
	return 0.6 if cle(p) == "BRECHE" else 1.0


static func silencieux(p: Pilote) -> bool:
	return cle(p) == "SNIPER"


static func invisible(p: Pilote) -> bool:
	return p.comp["camo_t"] > 0.0


static func surchauffe(p: Pilote) -> bool:
	return cle(p) == "ASSAUT" and p.comp["ult_t"] > 0.0


static func facteur_cadence(p: Pilote) -> float:
	return 1.6 if surchauffe(p) else 1.0


static func facteur_recul(p: Pilote) -> float:
	return 0.4 if surchauffe(p) else 1.0


static func cd_grappin(p: Pilote) -> float:
	return 1.0 if cle(p) == "ASSAUT" and niveau(p) >= 2 else 3.0


static func portee_grappin(p: Pilote) -> float:
	return 70.0 if cle(p) == "ASSAUT" and niveau(p) >= 2 else 50.0


static func sur_kill(p: Pilote) -> void:
	if cle(p) == "ASSAUT":
		var a := p.arme_active()
		if a != null and not a.melee():
			a.rech = minf(a.rech, 0.15)               # rechargement quasi immédiat
			a.cool = 0.0
		if surchauffe(p):
			p.hp = minf(p.hp_max, p.hp + 15.0)        # surchauffe : soin à chaque élimination


## Ranimation (ultime Tactique) : appelé quand les PV tombent à 0. Retourne true si sauvé.
static func reanimation(p: Pilote) -> bool:
	if cle(p) != "TACTIC" or niveau(p) < 3 or p.comp["cd_ultime"] > 0.0:
		return false
	p.comp["cd_ultime"] = CD_ULTIME["TACTIC"]
	p.hp = p.hp_max * 0.6
	p.invuln = 2.5
	if p == Etat.joueur:
		Etat.banniere.emit("RANIMATION !", 2.0)
	Fx.explosion(p.global_position + Vector3(0, 1, 0), 3.0, Color(0.3, 1, 0.5))
	return true


# --------------------------------------------------------------- boucle ----
static func tick(p: Pilote, dt: float) -> void:
	var d: Dictionary = p.comp
	d["cd_actif"] = maxf(0.0, d["cd_actif"] - dt)
	d["cd_ultime"] = maxf(0.0, d["cd_ultime"] - dt)
	d["radar_t"] = maxf(0.0, d["radar_t"] - dt)
	d["camo_t"] = maxf(0.0, d["camo_t"] - dt)
	if d["ult_t"] > 0.0:
		d["ult_t"] -= dt
		if cle(p) == "BRECHE" and (d["ult_t"] <= 0.0 or (p.arme_temp != null and p.arme_temp.munitions <= 0
				and p.arme_temp.reserve <= 0 and p.arme_temp.rech <= 0.0)):
			d["ult_t"] = 0.0
			p.arme_temp = null
			p.sur_changement_arme()
	var niv := niveau(p)
	if p == Etat.joueur and niv > d["niv_annonce"]:
		d["niv_annonce"] = niv
		if niv == 2:
			Etat.msg("Niveau 2 : %s (touche T)" % nom_actif(p))
		else:
			Etat.msg("Niveau 3 : %s (touche Y)" % nom_ultime(p))
	if cle(p) == "TACTIC":                              # sacoche : pack de soin / d'armure
		d["sacoche"] -= dt
		if d["sacoche"] <= 0.0:
			d["sacoche"] = 45.0
			var fw := -p.global_transform.basis.z
			fw.y = 0.0
			var pos := p.global_position + fw.normalized() * 1.5
			var type := "soin" if p.hp < p.hp_max * 0.9 or randf() < 0.5 else "armure"
			Etat.racine_loots.add_child(Loot.creer(Vector3(pos.x, p.global_position.y, pos.z), type, true))
			if p == Etat.joueur:
				Etat.msg("Sacoche déployée : pack de " + ("soin" if type == "soin" else "armure"))


# --------------------------------------------------------------- actions ----
static func utiliser_actif(p: Pilote) -> bool:
	if not p.vivant or p.mode == "titan" or niveau(p) < 2 or p.comp["cd_actif"] > 0.0:
		return false
	var c := cle(p)
	if c == "ASSAUT":
		return false                                   # le grappin éclair est passif (touche X)
	var fw := -p.global_transform.basis.z
	if p is Joueur:
		fw = -p.camera.global_transform.basis.z
	match c:
		"BRECHE":
			p.comp["cd_actif"] = CD_ACTIF[c]
			Etat.get_tree().current_scene.add_child(Grenade.creer(p, p.oeil() + fw * 0.8, fw * 22.0 + Vector3(0, 2, 0), "charge"))
			return true
		"SNIPER":
			p.comp["cd_actif"] = CD_ACTIF[c]
			p.comp["radar_t"] = RADAR_DUREE
			Fx.onde(p.global_position, RADAR_RAYON)
			if p == Etat.joueur:
				Etat.msg("Scan radar : ennemis révélés (%d m)" % int(RADAR_RAYON))
			return true
		"TACTIC":
			if p.bouclier != null and is_instance_valid(p.bouclier):
				p.bouclier.casser(false)
			var f := Vector3(fw.x, 0, fw.z).normalized()
			p.bouclier = Bouclier.creer(p, p.global_position + f * 2.6, atan2(-f.x, -f.z))
			Etat.get_tree().current_scene.add_child(p.bouclier)
			p.comp["cd_actif"] = CD_ACTIF[c]
			return true
	return false


static func utiliser_ultime(p: Pilote) -> bool:
	if not p.vivant or p.mode == "titan" or niveau(p) < 3 or p.comp["cd_ultime"] > 0.0:
		return false
	var c := cle(p)
	match c:
		"ASSAUT":
			p.comp["ult_t"] = SURCHAUFFE_DUREE
			p.comp["cd_ultime"] = CD_ULTIME[c]
			if p == Etat.joueur:
				Etat.banniere.emit("SURCHAUFFE !", 1.5)
			return true
		"BRECHE":
			p.arme_temp = Arme.creer("Lance-roquettes")
			p.comp["ult_t"] = ROQUETTES_DUREE
			p.comp["cd_ultime"] = CD_ULTIME[c]
			p.sur_changement_arme()
			if p == Etat.joueur:
				Etat.banniere.emit("LANCE-ROQUETTES", 1.5)
			return true
		"SNIPER":
			p.comp["camo_t"] = CAMO_DUREE
			p.comp["cd_ultime"] = CD_ULTIME[c]
			if p == Etat.joueur:
				Etat.banniere.emit("CAMOUFLAGE", 1.5)
			return true
	return false                                       # Tactique : ranimation automatique à la mort


## Texte HUD.
static func resume(p: Pilote) -> String:
	var niv := niveau(p)
	var d: Dictionary = p.comp
	var s := "Niv %d" % niv
	if niv >= 2 and cle(p) != "ASSAUT":
		s += "   [T] %s : %s" % [nom_actif(p), "prêt" if d["cd_actif"] <= 0.0 else "%ds" % ceili(d["cd_actif"])]
	elif cle(p) == "ASSAUT" and niv >= 2:
		s += "   Grappin éclair actif (X)"
	if niv >= 3:
		var ult: String = ("[Y] " if cle(p) != "TACTIC" else "") + nom_ultime(p)
		if d["ult_t"] > 0.0:
			s += "   %s : %ds" % [ult, ceili(d["ult_t"])]
		else:
			s += "   %s : %s" % [ult, "prêt" if d["cd_ultime"] <= 0.0 else "%ds" % ceili(d["cd_ultime"])]
	else:
		var total: int = p.craft["rouge"] + p.craft["orange"] + p.craft["bleu"] + p.craft["vert"]
		var objectif := NIVEAU2 if niv == 1 else NIVEAU3
		s += "   (niveau %d à %d loots : %d)" % [niv + 1, objectif, total]
	if d["camo_t"] > 0.0:
		s += "   CAMOUFLAGE %ds" % ceili(d["camo_t"])
	return s
