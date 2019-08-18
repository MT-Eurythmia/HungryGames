if minetest.is_singleplayer() then
	return
end

local storage = minetest.get_mod_storage()

local global_stats = {}
local function load_stats()
	local stats_str = storage:get("stats")
	if stats_str then
		global_stats = minetest.deserialize(stats_str)
	end
end
load_stats()

local function save_stats()
	storage:set_string("stats", minetest.serialize(global_stats))
end

local function update_global_stats(map)
	local kill_number = {}
	local kill_map = {}
	for killer, v in pairs(map.scores) do
		for killed, _ in pairs(v) do
			kill_number[killer] = (kill_number[killer] or 0) + 1
			kill_map[killed] = killer
		end
	end

	for i, name in ipairs(map.dead_players) do
		if not global_stats[name] then
			global_stats[name] = {
				kills = 0,
				games = 0,
				victories = 0,
				total_rank = 0, -- Divide by games to get the average rank (between 0 and 1)
				points = 0, -- Used for score calculation
			}
		end
		local entr = global_stats[name]
		entr.kills = entr.kills + (kill_number[name] or 0)
		entr.games = entr.games + 1
		if i == #map.dead_players then
			entr.victories = entr.victories + 1
			entr.points = entr.points + 1 -- Bonus point :)
		end
		entr.total_rank = entr.total_rank + 1 - (i - 1) / (#map.dead_players - 1)
		entr.points = entr.points + (kill_number[name] or 0) + (i - 1) / (#map.dead_players - 1)
		entr.last_game = os.time()
	end

	save_stats()
end

hg_match.register_on_end_game(update_global_stats)

local function show_stats_formspec(name)
	-- Sort stats
	local list = {}
	for k, v in pairs(global_stats) do
		local center = 7 -- seventh day is the central point of the curve
		local steepness_factor = 1/3
		local time_diff = steepness_factor * (os.difftime(os.time(), v.last_game) / (24 * 3600) - center)
		table.insert(list, {
			name = k,
			stats = table.copy(v),
			rank_score_factor = 1 - 0.5 * math.exp(time_diff) / (math.exp(time_diff) + 1)
		})
	end
	table.sort(list, function(a, b)
		return a.stats.points * a.rank_score_factor > b.stats.points * b.rank_score_factor
	end)

	-- Find the invoking player rank
	local own_rank
	for i, v in ipairs(list) do
		if v.name == name then
			own_rank = i
			break
		end
	end
	local own_stats = global_stats[name]

	local formspec = "size[14,8]" ..
		"tablecolumns[color;text,width=4;text,width=16;text,width=4;text,width=4;text,width=4;text,width=4;text,width=4]" ..
		"table[0,0;13.8,7;stats;#FFFFFF,Rank,Name,Total Games,Total Kills,Total Victories,Average Rank (/5),Total Score,"
	-- Insert own entry first
	if own_rank and own_stats then
		formspec = formspec .. string.format("#FF0000,%d,%s,%d,%d,%d,%.1f,%d,", own_rank, "you",
			own_stats.games,
			own_stats.kills,
			own_stats.victories,
			own_stats.total_rank / own_stats.games * 4 + 1,
			math.ceil(own_stats.points))
	end

	-- And all other entries
	for i, row in ipairs(list) do
		formspec = formspec .. string.format("#FFFFFF,%d,%s,%d,%d,%d,%.1f,%d,", i, row.name,
			row.stats.games,
			row.stats.kills,
			row.stats.victories,
			row.stats.total_rank / row.stats.games * 4 + 1,
			math.ceil(row.stats.points))
		if i > 50 then
			-- Do not show more than 50 players
			break
		end
	end
	formspec = string.sub(formspec, 1, -1) .. "]" ..
		"button_exit[6,7.3;2,1;exit;Close]"

	minetest.show_formspec(name, "stats", formspec)
end

minetest.register_chatcommand("stats", {
	params = "",
	description = "Show player statistics",
	privs = {},
	func = show_stats_formspec,
})
