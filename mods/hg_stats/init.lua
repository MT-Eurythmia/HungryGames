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
	-- Global stats store the following info:
	-- * Total number of kills,
	-- * Total number of games,
	-- * Average number of kills per player (which is less than one and represents how good the player is),
	-- * Average rank, as a percentage.
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
				total_opponents = 0, -- Divide kills by it to get kills_per_player (sorting key)
				total_rank = 0, -- Divide by games to get the average rank (between 0 and 1)
			}
		end
		local entr = global_stats[name]
		entr.kills = entr.kills + (kill_number[name] or 0)
		entr.games = entr.games + 1
		entr.total_opponents = entr.total_opponents + #map.dead_players - 1
		entr.total_rank = entr.total_rank + 1 - (i - 1) / (#map.dead_players - 1)
	end

	save_stats()
end

hg_match.register_on_end_game(update_global_stats)

local function show_stats_formspec(name)
	-- Sort stats
	local list = {}
	for k, v in pairs(global_stats) do
		table.insert(list, {
			name = k,
			stats = table.copy(v)
		})
	end
	table.sort(list, function(a, b)
		-- Kills-per-player is the sorting key.
		return a.stats.kills / a.stats.total_opponents > b.stats.kills / b.stats.total_opponents
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

	local formspec = "size[8,8]" ..
		"tablecolumns[text,align=right;text,padding=2;text,padding=2,align=right;text,padding=2]" ..
		"table[0,0;7.8,7;stats;Rank,Name,Total Games,Total Kills,Kills per 10 Opponents,Average Rank (norm. 10 players)"
	-- Insert own entry first
	if own_rank and own_stats then
		formspec = formspec .. string.format("%d,%s,%d,%d,%f,%f,", own_rank, "you",
			own_stats.games,
			own_stats.kills,
			own_stats.kills / own_stats.total_opponents * 10,
			own_stats.total_rank / own_stats.games * 9 + 1)
	end

	-- And all other entries
	for i, row in ipairs(list) do
		formspec = formspec .. string.format("%d,%s,%d,%d,%f,%f,", i, row.name,
			row.stats.games,
			row.stats.kills,
			row.stats.kills / row.stats.total_opponents * 10,
			row.stats.total_rank / row.stats.games * 9 + 1)
	end
	formspec = string.sub(formspec, 1, -1) .. "]" ..
		"button_exit[3,7.3;2,1;exit;Close]"

	minetest.show_formspec(name, "stats", formspec)
end

minetest.register_chatcommand("stats", {
	params = "",
	description = "Show player statistics",
	privs = {},
	func = show_stats_formspec,
})
