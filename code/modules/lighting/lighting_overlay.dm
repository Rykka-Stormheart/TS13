/datum/lighting_object
	///the underlay we are currently applying to our turf to apply light
	var/mutable_appearance/current_underlay

	///whether we are already in the SSlighting.objects_queue list
	var/needs_update = FALSE

	var/sunlight_affected = FALSE //Torchstation edit

	///the turf that our light is applied to
	var/turf/affected_turf

/datum/lighting_object/New(turf/source)
	if(!SSlighting.subsystem_initialized)
		stack_trace("lighting_object created before SSlighting up!")
		return
	if(!isturf(source))
		qdel(src, force=TRUE)
		stack_trace("a lighting object was assigned to [source], a non turf! ")
		return
	. = ..()

	current_underlay = mutable_appearance(LIGHTING_ICON, "transparent", source.z, PLANE_LIGHTING, 255, RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)

	affected_turf = source
	if (affected_turf.lighting_object)
		qdel(affected_turf.lighting_object, force = TRUE)
		stack_trace("a lighting object was assigned to a turf that already had a lighting object!")

	affected_turf.lighting_object = src
	affected_turf.set_luminosity(0)

	for(var/turf/space/space_tile in RANGE_TURFS(1, affected_turf))
		space_tile.update_starlight()

	needs_update = TRUE
	SSlighting.objects_queue += src

/datum/lighting_object/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE
	SSlighting.objects_queue -= src
	if (isturf(affected_turf))
		affected_turf.lighting_object = null
		affected_turf.set_luminosity(1)
		affected_turf.underlays -= current_underlay
	affected_turf = null
	return ..()

/datum/lighting_object/proc/update()

	// To the future coder who sees this and thinks
	// "Why didn't he just use a loop?"
	// Well my man, it's because the loop performed like shit.
	// And there's no way to improve it because
	// without a loop you can make the list all at once which is the fastest you're gonna get.
	// Oh it's also shorter line wise.
	// Including with these comments.

	var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new

	var/datum/lighting_corner/red_corner = affected_turf.lighting_corner_SW || dummy_lighting_corner
	var/datum/lighting_corner/green_corner = affected_turf.lighting_corner_SE || dummy_lighting_corner
	var/datum/lighting_corner/blue_corner = affected_turf.lighting_corner_NW || dummy_lighting_corner
	var/datum/lighting_corner/alpha_corner = affected_turf.lighting_corner_NE || dummy_lighting_corner

	var/max = max(red_corner.largest_color_luminosity, green_corner.largest_color_luminosity, blue_corner.largest_color_luminosity, alpha_corner.largest_color_luminosity)

	var/rr = red_corner.cache_r
	var/rg = red_corner.cache_g
	var/rb = red_corner.cache_b

	var/gr = green_corner.cache_r
	var/gg = green_corner.cache_g
	var/gb = green_corner.cache_b

	var/br = blue_corner.cache_r
	var/bg = blue_corner.cache_g
	var/bb = blue_corner.cache_b

	var/ar = alpha_corner.cache_r
	var/ag = alpha_corner.cache_g
	var/ab = alpha_corner.cache_b

	#if LIGHTING_SOFT_THRESHOLD != 0
	var/set_luminosity = max > LIGHTING_SOFT_THRESHOLD
	#else
	// Because of floating points™?, it won't even be a flat 0.
	// This number is mostly arbitrary.
	var/set_luminosity = max > 1e-6
	#endif

	//Torchedit Begin
	if(affected_turf.check_for_sun())
		var/datum/sun_holder/sun = SSplanets.z_to_planet[affected_turf.z].sun_holder
		var/outside_near = FALSE
		outer_loop:
			for(var/dir in cardinal)
				var/steps = 1
				var/turf/cur_turf = get_step(affected_turf,dir)
				while(cur_turf && !cur_turf.density && steps < 11)
					if(cur_turf.is_outdoors())
						outside_near = TRUE
						break outer_loop
					steps += 1
					cur_turf = get_step(cur_turf,dir)

		if(outside_near)
			sunlight_affected = TRUE
			SSlighting.sunlight_queue += src
			set_luminosity = TRUE
			var/brightness = sun.our_brightness * 0.6 * 0.1
			var/list/color = hex2rgb(sun.our_color)
			var/red = color[1] / 255.0
			var/green = color[2] / 255.0
			var/blue = color[3] / 255.0
			rr += brightness * red
			rg += brightness * green
			rb += brightness * blue
			gr += brightness * red
			gg += brightness * green
			gb += brightness * blue
			br += brightness * red
			bg += brightness * green
			bb += brightness * blue
			ar += brightness * red
			ag += brightness * green
			ab += brightness * blue
		else if(sunlight_affected)
			sunlight_affected = FALSE
			SSlighting.sunlight_queue -= src


	//Torchedit End
	if((rr & gr & br & ar) && (rg + gg + bg + ag + rb + gb + bb + ab == 8))
		//anything that passes the first case is very likely to pass the second, and addition is a little faster in this case
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = "transparent"
		current_underlay.color = null
		affected_turf.underlays |= current_underlay
	else if(!set_luminosity)
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = "dark"
		current_underlay.color = null
		affected_turf.underlays |= current_underlay
	else
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = "gradient"
		current_underlay.color = list(
			rr, rg, rb, 00,
			gr, gg, gb, 00,
			br, bg, bb, 00,
			ar, ag, ab, 00,
			00, 00, 00, 01
		)

		affected_turf.underlays |= current_underlay

	affected_turf.set_luminosity(set_luminosity)

/datum/lighting_object/proc/removefromturf()
	affected_turf.underlays -= current_underlay

/datum/lighting_object/proc/addtoturf()
	affected_turf.underlays |= current_underlay
