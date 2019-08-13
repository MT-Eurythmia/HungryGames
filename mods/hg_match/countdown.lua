hg_match.initial_countdown = 0
hg_match.wait_countdown = -1 -- -1 means that the countdown is stopped.
hg_match.new_players_20_min = 0

function hg_match.start_countdown()
	-- Average time to get 30 players based on the last 20 minutes activity.
	-- Maximum 5 minutes, except if there are more than 6 players per minute.
	local v = 30 * (20 * 60) / math.max(hg_match.new_players_20_min, 120)
	hg_match.initial_countdown = v
	hg_match.wait_countdown = v

	hg_match.call_registered_on_countdown_update(v, v, 0)
end

function hg_match.update_countdown(n)
	if #hg_match.players_waiting == 0 then
		hg_match.wait_countdown = -1
		return
	end
	if hg_match.wait_countdown < 0 then
		if not hg_match.waiting_player_flag and not hg_match.waiting_map_flag then
			hg_match.start_countdown()
		end
		return
	end

	-- If the countdown is below 10% of its initial value, it can only be reduced second
	-- by second.
	if n == 1 then
		hg_match.wait_countdown = hg_match.wait_countdown - 1
	elseif hg_match.wait_countdown > hg_match.initial_countdown / 10 then
		hg_match.wait_countdown = math.max(hg_match.wait_countdown - n, hg_match.initial_countdown / 10)
	end

	hg_match.call_registered_on_countdown_update(hg_match.initial_countdown, hg_match.wait_countdown, n)

	if hg_match.wait_countdown == 0 then
		hg_match.wait_countdown = -1
		hg_match.new_game()
		return
	end
end

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then
		return
	end

	timer = timer - 1
	hg_match.update_countdown(1)
end)

hg_match.register_on_new_player(function(name)
	hg_match.update_countdown(hg_match.initial_countdown / 20)

	hg_match.new_players_20_min = hg_match.new_players_20_min + 1
	minetest.after(20 * 60, function()
		hg_match.new_players_20_min = hg_match.new_players_20_min - 1
	end)
end)
