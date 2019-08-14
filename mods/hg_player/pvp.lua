-- Build time countdown
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then
		return
	end

	timer = timer - 1

	for _, map in ipairs(hg_map.maps) do
		if map.in_use and map.build_countdown >= 0 then
			map.build_countdown = map.build_countdown - 1

			if map.build_countdown == 0 then
				for _, name in ipairs(map.players) do
					minetest.chat_send_player(name, "End of build time. Fight!")
					hg_player.remove_text_hud(minetest.get_player_by_name(name))
					minetest.sound_play({name = "hg_player_build_end"}, {
						to_player = name,
					})
				end
				map.build_countdown = -1
			else
				local hud_text = string.format("Remaining build time: %d min %d s",
					math.floor(map.build_countdown / 60), map.build_countdown % 60)
				for _, name in ipairs(map.players) do
					hg_player.update_text_hud(minetest.get_player_by_name(name), hud_text)
				end
			end
		end
	end
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	local name = player:get_player_name()
	local map = hg_map.find_player_map(name)

	if not map or map.build_countdown > 0 then
		return true
	end
end)

minetest.register_on_dieplayer(function(player, reason)
	if reason and reason.type == "punch" and reason.object and reason.object:is_player() then
		hg_match.killed_player(player:get_player_name(), reason.object:get_player_name())
	else
		hg_match.killed_player(player:get_player_name())
	end
end)
