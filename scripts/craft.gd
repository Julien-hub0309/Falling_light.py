class_name Craft
extends RefCounted
## Système de craft (Craft/*.py). Chaque loot ramassé fait progresser le pilote :
##   ROUGE (arme)    : compteur -> 3 : mêlée +25 %, 5 : arme de classe, 10 : arme améliorée
##   ORANGE (grenade): +1 grenade (max 6)
##   BLEU (armure)   : kit d'armure (max 3) -> touche V, +40 armure (max 100)
##   VERT (soin)     : kit de soin  (max 3) -> touche H, +40 PV
## Le craft est stocké dans `pilote.craft` (dictionnaire) et remis à zéro à chaque partie.

const PALIER_MELEE := 3
const PALIER_CLASSE := 5
const PALIER_AUGMENT := 10
const BONUS_MELEE := 0.25
const AUGMENTATION := {"degats": 1.35, "cadence": 1.2, "chargeur": 1.5}
const GAIN_VIE := 40.0
const GAIN_ARMURE := 40.0
const MAX_KITS := 3
const MAX_GRENADES := 6
## classe -> arme de classe (craft_classe.py)
const ARMES_CLASSE := {"ASSAUT": "AR-15", "TACTIC": "Kriss Vector", "SNIPER": "DRS-50", "BRECHE": "Pompe"}


static func neuf() -> Dictionary:
	return {"rouge": 0, "orange": 0, "bleu": 0, "vert": 0, "kits_soin": 0, "kits_armure": 0,
		"niveau_melee": 0, "arme_classe": false, "augmentation": false}


static func msg(p: Pilote, texte: String) -> void:
	if p == Etat.joueur:
		Etat.msg(texte)


static func arme_de_classe(p: Pilote) -> String:
	return ARMES_CLASSE.get(p.classe.get("nom", ""), "Pistolet")


## Retourne 1 = loot pris, 0 = refusé (il reste au sol), -1 = pas géré par le craft
## (comportement normal du pilote : munitions, et arme au sol tant qu'il n'a pas son arme de classe).
static func on_loot(p: Pilote, type: String) -> int:
	var d: Dictionary = p.craft
	match type:
		"arme":
			d["rouge"] += 1
			_verifier(p)
			return 1 if d["arme_classe"] else -1
		"grenade":
			d["orange"] += 1
			if p.nb_tactique >= MAX_GRENADES:
				msg(p, "Stock de grenades plein.")
				return 0
			p.nb_tactique += 1
			msg(p, "Grenade %s craftée (%d/%d)" % [p.tactique, p.nb_tactique, MAX_GRENADES])
			return 1
		"armure":
			d["bleu"] += 1
			if d["kits_armure"] >= MAX_KITS:
				msg(p, "Kits d'armure au maximum.")
				return 0
			d["kits_armure"] += 1
			msg(p, "Kit d'armure crafté (%d/%d) - touche V" % [d["kits_armure"], MAX_KITS])
			return 1
		"soin":
			d["vert"] += 1
			if d["kits_soin"] >= MAX_KITS:
				msg(p, "Kits de soin au maximum.")
				return 0
			d["kits_soin"] += 1
			msg(p, "Kit de soin crafté (%d/%d) - touche H" % [d["kits_soin"], MAX_KITS])
			return 1
	return -1


static func _verifier(p: Pilote) -> void:
	var d: Dictionary = p.craft
	var n: int = d["rouge"]
	if n == PALIER_MELEE and d["niveau_melee"] == 0:
		d["niveau_melee"] = 1
		msg(p, "Amélioration mêlée : +%d %% de dégâts !" % int(BONUS_MELEE * 100))
	if n >= PALIER_CLASSE and not d["arme_classe"]:
		d["arme_classe"] = true
		msg(p, "Nouvelle arme débloquée : " + arme_de_classe(p))
		donner_arme_classe(p)
	if n == PALIER_AUGMENT and not d["augmentation"] and d["arme_classe"]:
		d["augmentation"] = true
		msg(p, "Arme à feu améliorée !")
	appliquer(p)


static func donner_arme_classe(p: Pilote) -> void:
	p.armes[0] = Arme.creer(arme_de_classe(p))
	p.sur_changement_arme()


## Applique les bonus de craft aux armes du pilote (idempotent : un drapeau par amélioration).
static func appliquer(p: Pilote) -> void:
	var d: Dictionary = p.craft
	for a in p.armes:
		if a.melee() and d["niveau_melee"] > 0 and not a.aug_melee:
			a.degats *= 1.0 + BONUS_MELEE * d["niveau_melee"]
			a.aug_melee = true
		if d["augmentation"] and d["arme_classe"] and not a.melee() and not a.augmentee \
				and a.modele == arme_de_classe(p):
			a.degats *= AUGMENTATION["degats"]
			a.cadence /= AUGMENTATION["cadence"]
			a.chargeur = int(a.chargeur * AUGMENTATION["chargeur"])
			a.munitions = a.chargeur
			a.augmentee = true


## Après (re)création des armes (respawn) : le craft déjà obtenu est conservé.
static func apres_classe(p: Pilote) -> void:
	if p.craft["arme_classe"]:
		p.armes[0] = Arme.creer(arme_de_classe(p))
	appliquer(p)


static func utiliser_soin(p: Pilote) -> bool:
	var d: Dictionary = p.craft
	if d["kits_soin"] <= 0 or not p.vivant or p.mode == "titan" or p.hp >= p.hp_max:
		return false
	d["kits_soin"] -= 1
	p.hp = minf(p.hp_max, p.hp + GAIN_VIE)
	msg(p, "Kit de soin utilisé +%d PV" % int(GAIN_VIE))
	return true


static func utiliser_armure(p: Pilote) -> bool:
	var d: Dictionary = p.craft
	if d["kits_armure"] <= 0 or not p.vivant or p.mode == "titan" or p.armure >= p.armure_max:
		return false
	d["kits_armure"] -= 1
	p.armure = minf(p.armure_max, p.armure + GAIN_ARMURE)
	msg(p, "Kit d'armure utilisé +%d" % int(GAIN_ARMURE))
	return true


## Texte de progression pour le HUD.
static func resume(p: Pilote) -> String:
	var d: Dictionary = p.craft
	var n: int = d["rouge"]
	var suite := ""
	if n < PALIER_MELEE:
		suite = "mêlée +25 %% à %d" % PALIER_MELEE
	elif n < PALIER_CLASSE:
		suite = "arme de classe à %d" % PALIER_CLASSE
	elif n < PALIER_AUGMENT and d["arme_classe"]:
		suite = "arme améliorée à %d" % PALIER_AUGMENT
	return "Kits  [H] soin %d/%d   [V] armure %d/%d      Craft rouge %d%s" % [
		d["kits_soin"], MAX_KITS, d["kits_armure"], MAX_KITS, n, (" (" + suite + ")") if suite != "" else ""]
