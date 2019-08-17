--[[
The code is this file is responsible for deciding when to start a game. It checks
every second whether to do so.
]]

function hg_match.starter_step()
	if hg_match.start_delay then
		-- A start is scheduled after some delay
		hg_match.start_delay = hg_match.start_delay - 1
		if hg_match.start_delay == 0 then
			hg_match.start_delay = nil
		else
			hg_player.update_text_hud_all(hg_match.players_waiting, string.format("The game will start in %d seconds...", hg_match.start_delay))
			return
		end
	end

	-- If there are less than two players, it's certain that we can't start a game.
	local n_players = #minetest.get_connected_players()
	if n_players < 2 then
		hg_player.update_text_hud_all(hg_match.players_waiting, "The game will start as soon as another player is ready...")
		return
	end

	-- Read the maximum number of players to wait to start a game.
	local max_players_waited = tonumber(minetest.settings:get("hg.max_players_waited")) or hg_match.max_players
	if max_players_waited > hg_match.max_players then
		minetest.log("warning", string.format("hg.max_players_waited set to %d, but no map can handle more than %d players.",
			max_players_waited, hg_match.max_players))
		max_players_waited = hg_match.max_players
	elseif max_players_waited < 2 then
		minetest.log("warning", string.format("hg.max_players_waited must be at least 2, set to %d.",
			max_players_waited))
		max_players_waited = 2
	end
	-- Compute the number of players to wait based on the number of connected players
	local players_waited
	if n_players <= 2 then
		-- We need at least two players
		players_waited = 2
	elseif n_players <= 5 then
		-- Up to 5 players, wait all the players
		players_waited = n_players
	else
		-- Wait for the ceil of the square root of the number of players
		players_waited = math.ceil(math.sqrt(n_players))
	end
	-- But never more than max_players_waited.
	if players_waited > max_players_waited then
		players_waited = max_players_waited
	end

	if #hg_match.players_waiting < players_waited then
		-- Not enough players
		hg_player.update_text_hud_all(hg_match.players_waiting, string.format("The game will start as soon as %d players are ready (it shouldn't take long)...",
			players_waited))
		return
	end

	-- Also check that there is a map ready
	local map_ready = false
	for _, map in ipairs(hg_map.maps) do
		if map.ready then
			map_ready = true
			break
		end
	end
	if not map_ready then
		hg_player.update_text_hud_all(hg_match.players_waiting, "The game will start as soon as a map is ready...")
		return
	end

	-- We can now start a game.
	if hg_match.last_game_time and os.difftime(os.time(), hg_match.last_game_time) < 15 then
		-- If a game ended less than 15 seconds ago, wait 15 seconds before starting
		-- the next game to let players respawn, say each other Good Game, and rest
		-- for a bit.
		hg_match.start_delay = 15 - os.difftime(os.time(), hg_match.last_game_time)
	else
		hg_match.new_game()
	end
end

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then
		return
	end

	timer = timer - 1
	hg_match.starter_step()
end)
