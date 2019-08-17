if minetest.is_singleplayer() then
	return
end

hg_player = {}

dofile(minetest.get_modpath("hg_player") .. "/hud.lua")
dofile(minetest.get_modpath("hg_player") .. "/pvp.lua")
dofile(minetest.get_modpath("hg_player") .. "/ranking_formspec.lua")

local function clear_inventory(player)
	-- Inventory
	local inv = player:get_inventory()
	inv:set_list("main", {})
	inv:set_list("craft", {})

	-- Armor
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
end

function hg_player.new_player(name)
	-- Revoke interact
	local privs = minetest.get_player_privs(name)
	privs.interact = nil
	privs.shout = true
	minetest.set_player_privs(name, privs)

	-- Set pos
	local player = minetest.get_player_by_name(name)
	local spawnpoints = hg_map.spawn.hg_nodes.spawnpoint
	player:set_pos(vector.add(spawnpoints[math.random(#spawnpoints)],
		vector.new(0, 1, 0)))

	-- Stop hunger
	hg_hunger.stop_hunger(player)

	-- Clear inventory
	clear_inventory(player)

	-- Set clouds height
	player:set_clouds({
		height = hg_map.spawn.maxp.y
	})
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()

	minetest.chat_send_player(name, "Hungry Games Redo is currently extremely unstable. The game may crash at any time. Please report any bug to the server administrator.\nThank you for playing Hungry Games!")

	hg_match.new_player(name)
end)

minetest.register_on_leaveplayer(function(player)
	hg_match.remove_player(player:get_player_name())
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

function hg_player.new_game(map)
	local spawnpoints = table.copy(map.hg_nodes.spawnpoint)
	for _, name in ipairs(map.players) do
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
		clear_inventory(player)

		-- Teleport the player to a spawn point
		local sp_i = math.random(#spawnpoints)
		player:set_pos(vector.add(spawnpoints[sp_i],
			vector.new(0, 1, 0)))
		table.remove(spawnpoints, sp_i)

		-- Set clouds height
		player:set_clouds({
			height = map.maxp.y
		})

		-- Announce
		minetest.chat_send_player(name, string.format("Welcome to map %s made by @%s!", map.name, map.author))
		minetest.sound_play({name = "hg_player_match_start"}, {
			to_player = name,
		})
	end
end

function hg_player.end_game(map)
	for _, name in ipairs(map.dead_players) do
		minetest.sound_play({name = "hg_player_match_start"}, {
			to_player = name,
		})
	end
	hg_player.show_ranking_formspec(map)
end
