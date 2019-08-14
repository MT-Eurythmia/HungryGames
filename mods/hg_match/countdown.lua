hg_match.initial_countdown = 0
hg_match.wait_countdown = 0
hg_match.new_players_20_min = 0

function hg_match.init_countdown()
	-- Average time to get 20 players based on the last 20 minutes activity.
	-- Maximum 5 minutes, minimum 30 seconds
	local minutes_per_player = (20 * 60) / hg_match.new_players_20_min
	local v = math.max(math.min(20 * minutes_per_player, 300), 30)
	hg_match.initial_countdown = v
	hg_match.wait_countdown = v

	hg_match.call_registered_on_countdown_update(v, v)
end

function hg_match.update_countdown()
	if #minetest.get_connected_players() == 0 then
		-- Do not run the countdown when no player is connected,
		-- and leave it in a ready state
		hg_match.waiting_player_flag = false
		hg_match.waiting_map_flag = false
		hg_match.init_countdown()
	end

	if hg_match.waiting_player_flag or hg_match.waiting_map_flag then
		return
	end

	hg_match.wait_countdown = hg_match.wait_countdown - 1

	hg_match.call_registered_on_countdown_update(hg_match.initial_countdown, hg_match.wait_countdown)

	if hg_match.wait_countdown == 0 then
		hg_match.init_countdown()
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
	hg_match.update_countdown()
end)

hg_match.register_on_new_player(function(name)
	hg_match.new_players_20_min = hg_match.new_players_20_min + 1
	minetest.after(20 * 60, function()
		hg_match.new_players_20_min = hg_match.new_players_20_min - 1
	end)
end)

hg_match.init_countdown()
