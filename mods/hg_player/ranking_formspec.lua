hg_player.respawn_ranking_formspec = {}

local function show_ranking_formspec(map)
	local kill_map = {}
	local kill_number = {}
	for killer, v in pairs(map.scores) do
		for killed, _ in pairs(v) do
			kill_map[killed] = killer
			kill_number[killer] = (kill_number[killer] or 0) + 1
		end
	end

	local rows = {}
	for _, name in ipairs(map.dead_players) do
		table.insert(rows, 1, {name, kill_number[name] or 0, kill_map[name] or "N/A"})
	end

	local formspec = "size[8,8]" ..
		"tablecolumns[text,align=right;text,padding=2;text,padding=2,align=right;text,padding=2]" ..
		"table[0,0;7.8,7;ranking;Rank,Name,Kills,Killed by,"
	for i, row in ipairs(rows) do
		formspec = formspec .. i .. "," .. row[1] .. "," .. row[2] .. "," .. row[3] .. ","
	end
	formspec = string.sub(formspec, 1, -1) .. "]" ..
		"button_exit[3,7.3;2,1;exit;Close]"

	for _, name in ipairs(map.dead_players) do
		minetest.show_formspec(name, "ranking", formspec)
	end

	hg_player.respawn_ranking_formspec[map.dead_players[#map.dead_players-1]] = formspec
end

hg_match.register_on_end_game(show_ranking_formspec)

--[[
function hg_player.debug_show_ranking_formspec()
	local players = minetest.get_connected_players()
	local map = {
		dead_players = {},
		scores = {},
	}

	for i, player in ipairs(players) do
		local name = player:get_player_name()
		table.insert(map.dead_players, name)
		map.scores[name] = {}
		if i == 2 then
			map.scores[name][players[1]:get_player_name()] = true
		end
	end

	show_ranking_formspec(map)
end
]]
