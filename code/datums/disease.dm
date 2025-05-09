
/*

IMPORTANT NOTE: Please delete the diseases by using cure() proc or del() instruction.
Diseases are referenced in a global list, so simply setting mob or obj vars
to null does not delete the object itself. Thank you.

*/

GLOBAL_LIST_INIT(diseases, typesof(/datum/disease) - /datum/disease)


/datum/disease
	var/form = "Virus" //During medscans, what the disease is referred to as
	var/name = "No disease"
	var/stage = 1 //all diseases start at stage 1
	var/max_stages = 0
	var/cure = null
	var/cure_id = null// reagent.id or list containing them
	var/cure_list = null // allows for multiple possible cure combinations
	var/cure_chance = 8//chance for the cure to do its job
	var/spread = null //spread type description
	var/initial_spread = null
	var/spread_type = AIRBORNE
	var/contagious_period = 0//the disease stage when it can be spread
	var/list/affected_species = list()
	var/mob/living/carbon/affected_mob = null //the mob which is affected by disease.
	var/holder = null //the atom containing the disease (mob or obj)
	var/carrier = 0 //there will be a small chance that the person will be a carrier
	var/curable = 0 //can this disease be cured? (By itself...)
	var/list/strain_data = list() //This is passed on to infectees
	var/stage_prob = 4 // probability of advancing to next stage, default 4% per check
	var/agent = "some microbes"//name of the disease agent
	var/permeability_mod = 1//permeability modifier coefficient.
	var/desc = null//description. Leave it null and this disease won't show in med records.
	var/severity = null//severity descr
	var/longevity = 150//time in "ticks" the virus stays in inanimate object (blood stains, corpses, etc). In syringes, bottles and beakers it stays infinitely.
	var/list/hidden = list(0, 0)
	// if hidden[1] is true, then virus is hidden from medical scanners
	// if hidden[2] is true, then virus is hidden from PANDEMIC machine
	var/can_carry = 1 // If the disease allows "carriers".
	var/age = 0 // age of the disease in the current mob
	var/stage_minimum_age = 0 // how old the disease must be to advance per stage
	var/survive_mob_death = FALSE //whether the virus continues processing as normal when the affected mob is dead.


/datum/disease/proc/stage_act()
	age++
	var/cure_present = has_cure()

	if(carrier && !cure_present)
		return

	spread = (cure_present?"Remissive":initial_spread)
	if(stage > max_stages)
		stage = max_stages

	if(!cure_present && prob(stage_prob) && age > stage_minimum_age) //now the disease shouldn't get back up to stage 4 in no time
		stage = min(stage + 1, max_stages)
		age = 0

	else if(cure_present && prob(cure_chance))
		stage = max(stage - 1, 1)

	if(stage <= 1 && ((prob(1) && curable) || (cure_present && prob(cure_chance))))
		cure()
		return
	return

/datum/disease/proc/has_cure()//check if affected_mob has required reagents.
	if(!cure_id)
		return 0
	var/result = 1
	if(cure_list == list(cure_id))
		if(istype(cure_id, /list))
			for(var/C_id in cure_id)
				if(!affected_mob.reagents.has_reagent(C_id))
					result = 0
					break
		else if(!affected_mob.reagents.has_reagent(cure_id))
			result = 0
	else
		for(var/C_list in cure_list)
			if(istype(C_list, /list))
				for(var/C_id in cure_id)
					if(!affected_mob.reagents.has_reagent(C_id))
						result = 0
						break
			else if(!affected_mob.reagents.has_reagent(C_list))
				result = 0

	return result

/datum/disease/proc/spread_by_touch()
	switch(spread_type)
		if(CONTACT_FEET, CONTACT_HANDS, CONTACT_GENERAL)
			return 1
	return 0

/datum/disease/proc/spread(atom/source=null, airborne_range = 2, force_spread)

	// If we're overriding how we spread, say so here
	var/how_spread = spread_type
	if(force_spread)
		how_spread = force_spread

	if(how_spread == SPECIAL || how_spread == NON_CONTAGIOUS || how_spread == BLOOD)//does not spread
		return FALSE

	if(stage < contagious_period) //the disease is not contagious at this stage
		return FALSE

	if(!source)//no holder specified
		if(affected_mob)//no mob affected holder
			source = affected_mob
		else //no source and no mob affected. Rogue disease. Break
			return FALSE

	var/mob/source_mob = source
	if(istype(source_mob) && !source_mob.can_pass_disease())
		return FALSE

	var/check_range = airborne_range//defaults to airborne - range 2

	if(how_spread != AIRBORNE && how_spread != SPECIAL)
		check_range = 1 // everything else, like infect-on-contact things, only infect things on top of it

	if(isturf(source.loc))
		FOR_DOVIEW(var/mob/living/carbon/victim, check_range, source, HIDE_INVISIBLE_OBSERVER)
			if(isturf(victim.loc) && victim.can_pass_disease())
				if(AStar(source.loc, victim.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, check_range))
					victim.contract_disease(src, 0, 1, force_spread)
		FOR_DOVIEW_END

	return


/datum/disease/process()
	if(!holder)
		SSdisease.all_diseases -= src
		return
	if(prob(65))
		spread(holder)

	if(affected_mob)
		for(var/datum/disease/D in affected_mob.viruses)
			if(D != src)
				if(IsSame(D))
					//error("Deleting [D.name] because it's the same as [src.name].")
					qdel(D) // if there are somehow two viruses of the same kind in the system, delete the other one

	if(holder == affected_mob)
		if((affected_mob.stat != DEAD) || survive_mob_death) //he's alive or disease transcends death.
			stage_act()
		else //he's dead.
			if(spread_type!=SPECIAL)
				spread_type = CONTACT_GENERAL
	if(!affected_mob || affected_mob.stat == DEAD) //the virus is in inanimate obj

		if(prob(70))
			if(--longevity<=0)
				cure(0)
	return

/datum/disease/proc/cure(resistance=1)//if resistance = 0, the mob won't develop resistance to disease
	if(affected_mob)
		if(resistance && !(type in affected_mob.resistances))
			var/saved_type = "[type]"
			affected_mob.resistances += text2path(saved_type)
		remove_virus()
	qdel(src) //delete the datum to stop it processing
	return


//unsafe proc, call cure() instead
/datum/disease/proc/remove_virus()
	affected_mob.viruses -= src
	if(ishuman(affected_mob))
		var/mob/living/carbon/human/H = affected_mob
		H.med_hud_set_status()

/datum/disease/New(process=TRUE)//process = 1 - adding the object to global list. List is processed by master controller.
	cure_list = list(cure_id) // to add more cures, add more vars to this list in the actual disease's New()
	if(process)  // Viruses in list are considered active.
		SSdisease.all_diseases += src
	initial_spread = spread

/datum/disease/proc/IsSame(datum/disease/D)
	if(istype(src, D.type))
		return 1
	return 0

/datum/disease/proc/Copy(process = TRUE)
	return new type(process)


/datum/disease/Destroy()
	affected_mob = null
	holder = null
	SSdisease.all_diseases -= src
	. = ..()
