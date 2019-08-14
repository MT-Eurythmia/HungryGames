if minetest.is_singleplayer() then
	return
end

hg_match = {
	players_waiting = {},
	max_players = 0,
	waiting_player_flag = false,
	waiting_map_flag = false,
}

function debug_msg(msg)
	if hg_match.debug then
		minetest.log("action", "[hg_match] " .. msg .. "\n" .. debug.traceback())
	end
end

for _, v in ipairs({"new_game", "end_game", "countdown_update", "new_player", "killed_player"}) do
	hg_match["registered_on_" .. v] = {}
	hg_match["register_on_" .. v] = function(f)
		assert(type(f) == "function")
		table.insert(hg_match["registered_on_" .. v], f)
	end
	hg_match["call_registered_on_" .. v] = function(...)
		for _, f in ipairs(hg_match["registered_on_" .. v]) do
			f(...)
		end
	end

	-- This is a default function, many of them are overwritten later in this
	-- file.
	hg_match[v] = hg_match["call_registered_on_" .. v]
end

for i, v in ipairs(hg_map.available_maps) do
	if v.max_players > hg_match.max_players then
		hg_match.max_players = v.max_players
	end
end

function hg_match.is_waiting(name)
	for _, v in ipairs(hg_match.players_waiting) do
		if name == v then
			return true
		end
	end
	return false
end

function hg_match.new_game()
	debug_msg("Called new_game")

	-- Check if there are enough players
	if #hg_match.players_waiting < 2 then
		debug_msg("Not enough players")

		hg_match.waiting_player_flag = true
		hg_match.call_registered_on_countdown_update(hg_match.initial_countdown, 0, 0,
			"The game will start as soon as at least 2 players are ready.")
		return false
	end

	-- Get a map
	local map = hg_map.get_map(#hg_match.players_waiting)
	if not map then
		debug_msg("No map is ready")
		hg_match.waiting_map_flag = true
		hg_match.call_registered_on_countdown_update(hg_match.initial_countdown, 0, 0,
			"The game will start as soon as a map is ready.")
		return false
	end

	local players = table.copy(hg_match.players_waiting)
	hg_match.players_waiting = {}

	map.in_use = true
	map.players = players
	map.dead_players = {}
	map.build_countdown = 5*60
	map.scores = {}
	for _, name in ipairs(players) do
		map.scores[name] = {}
	end

	minetest.log("action", string.format("[hg_match] Starting a new game with %d players on map %d (%s)!", #players, map.id, map.name))
	hg_match.call_registered_on_new_game(map, players)

	return true
end

function hg_match.end_game(map)
	debug_msg("Called end_game on map " .. map.id)

	minetest.log("action", string.format("[hg_match] End of game on map %d.", map.id))

	map.in_use = false
	map.ready = false
	for i, name in ipairs(map.players) do
		table.remove(map.players, i)
		table.insert(map.dead_players, name)
		hg_match.call_registered_on_killed_player(name, map)
		hg_match.new_player(name)
	end

	hg_match.call_registered_on_end_game(map)
end

function hg_match.new_player(name)
	debug_msg("Called new_player with params " .. name)

	hg_match.call_registered_on_new_player(name)

	if hg_match.is_waiting(name) then
		return
	end

	table.insert(hg_match.players_waiting, name)

	if hg_match.waiting_player_flag then
		debug_msg("Starting a game because the waiting_player_flag is set")
		hg_match.waiting_player_flag = false
		minetest.after(2, hg_match.new_game)
		return
	end

	if #hg_match.players_waiting >= hg_match.max_players then
		debug_msg("Starting a game because no map is able to handle more players")
		hg_match.new_game()
		return
	end
end

function hg_match.remove_player(name)
	debug_msg("Called remove_player with params " .. name)

	-- Is he waiting?
	for i, v in ipairs(hg_match.players_waiting) do
		if v == name then
			table.remove(hg_match.players_waiting, i)
			return
		end
	end

	-- Else let's suppose he's playing.
	debug_msg("Remove_player: player not found waiting, supposed playing")
	hg_match.killed_player(name)
end

function hg_match.killed_player(name, killer_name)
	debug_msg("Called killed_player with params " .. name .. " and " .. (killer_name or "nil"))

	local map, player_index = hg_map.find_player_map(name)
	if not map then
		return
	end

	debug_msg("Killed_player: player found on map " .. map.id)

	table.remove(map.players, player_index)
	table.insert(map.dead_players, name)

	hg_match.call_registered_on_killed_player(name, map, killer_name)

	if killer_name then
		map.scores[killer_name][name] = true
		hg_map.chat_send_map(map, string.format("Player %s was killed by %s!", name, killer_name))
	else
		hg_map.chat_send_map(map, string.format("Player %s died!", name))
	end

	if #map.players < 2 then
		hg_match.end_game(map)
	end
end

dofile(minetest.get_modpath("hg_match") .. "/countdown.lua")
