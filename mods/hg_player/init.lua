if minetest.is_singleplayer() then
	return
end

dofile(minetest.get_modpath("hg_player") .. "/hud.lua")
dofile(minetest.get_modpath("hg_player") .. "/pvp.lua")
dofile(minetest.get_modpath("hg_player") .. "/ranking_formspec.lua")

hg_match.register_on_new_player(function(name)
	-- Revoke interact
	minetest.set_player_privs(name, {
		shout = true,
	})
	-- Set pos
	local spawnpoints = hg_map.spawn.hg_nodes.spawnpoint
	minetest.get_player_by_name(name):set_pos(vector.add(spawnpoints[math.random(#spawnpoints)],
		vector.new(0, 1, 0)))
	-- Stop hunger
	hg_hunger.stop_hunger(minetest.get_player_by_name(name))
end)

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()

	minetest.chat_send_player(name, "Hungry Games Redo is currently extremely unstable. The game may crash at any time. Please report any bug to the server administrator.\nThank you for playing Hungry Games!")

	minetest.set_player_privs(name, {
		shout = true,
	})

	local spawnpoints = hg_map.spawn.hg_nodes.spawnpoint
	player:set_pos(vector.add(spawnpoints[math.random(#spawnpoints)],
		vector.new(0, 1, 0)))

	hg_hunger.stop_hunger(player)
	hg_match.new_player(player:get_player_name())
end)

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()

	if hg_match.is_waiting(name) then
		return
	end

	hg_hunger.stop_hunger(player)
	minetest.sound_play({name = "hg_player_death"}, {
		to_player = name,
	})
end)

minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	local formspec = hg_player.respawn_ranking_formspec[name]
	if formspec then
		minetest.after(1, function()
			minetest.show_formspec(name, "ranking", formspec)
		end)
		hg_player.respawn_ranking_formspec[name] = nil
	end

	hg_match.new_player(name)

	return true
end)

hg_match.register_on_new_game(function(map, players)
	local spawnpoints = table.copy(map.hg_nodes.spawnpoint)
	for _, name in ipairs(players) do
		local player = minetest.get_player_by_name(name)

		-- Grant interact
		local privs = minetest.get_player_privs(name)
		privs.interact = true
		minetest.set_player_privs(name, privs)

		-- Set HP
		player:set_hp(20)

		-- Start hunger
		hg_hunger.start_hunger(player)

		-- Clear inventory
		local inv = player:get_inventory()
		inv:set_list("main", {})
		inv:set_list("craft", {})
		-- Armor is a bit more complex
		local _, armor_inv = armor:get_valid_player(player, "[hg_match.on_new_game]")
		if armor_inv then
			for i = 1, armor_inv:get_size("armor") do
				local stack = armor_inv:get_stack("armor", i)
				if stack:get_count() > 0 then
					armor:set_inventory_stack(player, i, nil)
					armor:run_callbacks("on_unequip", player, i, stack)
				end
			end
			armor:set_player_armor(player)
		end

		-- Teleport the player to a spawn point
		local sp_i = math.random(#spawnpoints)
		player:set_pos(vector.add(spawnpoints[sp_i],
			vector.new(0, 1, 0)))
		table.remove(spawnpoints, sp_i)

		-- Announce
		minetest.chat_send_player(name, string.format("Welcome to map %s made by @%s!", map.name, map.author))
		minetest.sound_play({name = "hg_player_match_start"}, {
			to_player = name,
		})
	end
end)

hg_match.register_on_end_game(function(map)
	for _, name in ipairs(map.dead_players) do
		minetest.sound_play({name = "hg_player_match_start"}, {
			to_player = name,
		})
	end
end)
