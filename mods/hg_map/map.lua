-- Much of the code here (recognizable as being the best-written) was
-- initially written by Rubenwardy for the CaptureTheFlag subgame.

-- assert(minetest.get_mapgen_setting("mg_name") == "singlenode", "singlenode mapgen is required.")
minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode"})
end)

minetest.register_alias("mapgen_singlenode", "hg_map:ignore")

math.randomseed(os.time())

hg_map.chests_stuff = {
	["default:apple"]   = 200,
	["default:torch"]   = 200,
	["default:cobble"]  = 300,
	["default:wood"]    = 300,
	["3d_armor:helmet_wood"]        = 70,
	["3d_armor:chestplate_wood"]    = 70,
	["3d_armor:leggings_wood"]      = 70,
	["3d_armor:boots_wood"]         = 70,
	["shields:shield_wood"]         = 70,
	["3d_armor:helmet_steel"]       = 30,
	["3d_armor:chestplate_steel"]   = 30,
	["3d_armor:leggings_steel"]     = 30,
	["3d_armor:boots_steel"]        = 30,
	["shields:shield_steel"]        = 30,
	["3d_armor:helmet_bronze"]      = 20,
	["3d_armor:chestplate_bronze"]  = 20,
	["3d_armor:leggings_bronze"]    = 20,
	["3d_armor:boots_bronze"]       = 20,
	["shields:shield_bronze"]       = 20,
	["3d_armor:helmet_gold"]        = 13,
	["3d_armor:chestplate_gold"]    = 13,
	["3d_armor:leggings_gold"]      = 13,
	["3d_armor:boots_gold"]         = 13,
	["shields:shield_gold"]         = 13,
	["3d_armor:helmet_diamond"]     = 8,
	["3d_armor:chestplate_diamond"] = 8,
	["3d_armor:leggings_diamond"]   = 8,
	["3d_armor:boots_diamond"]      = 8,
	["shields:shield_diamond"]      = 8,
	["default:sword_wood"]    = 100,
	["default:sword_steel"]   = 50,
	["default:sword_bronze"]  = 37,
	["default:sword_diamond"] = 15,
	["default:sword_mese"]    = 10,
	["throwing:arrow"]      = 200,
	["throwing:arrow_gold"] = 100,
	["throwing:bow_wood"]   = 50,
	["throwing:bow_steel"]  = 20,
	["farming:cotton"]      = 70,
	["default:steel_ingot"]  = 100,
	["default:bronze_ingot"] = 50,
	["default:gold_ingot"]   = 40,
	["default:diamond"]      = 20,
	["default:mese_crystal"] = 15,
	["default:coal_lump"]    = 80,
	["tnt:tnt"]       = 10,
	["tnt:gunpowder"] = 50,
	["bucket:bucket_empty"]   = 20,
	["hg_hunger:water_glass"] = 70,
}

hg_map.mapdir = minetest.get_worldpath() .. "/hg_maps/"

hg_map.maps = {}

function hg_map.load_map_meta(idx, name)
	local meta = Settings(hg_map.mapdir .. name .. ".conf")

	local hg_nodes = minetest.deserialize(meta:get("hg_nodes"))

	local map = {
		idx         = idx,
		name        = name:split("/")[2],
		path        = hg_map.mapdir .. name,
		hg_nodes    = hg_nodes,
		width       = tonumber(meta:get("width")),
		length      = tonumber(meta:get("length")),
		height      = tonumber(meta:get("height")),
		margin      = tonumber(meta:get("margin")),
		blocksize   = tonumber(meta:get("blocksize")),
		author      = meta:get("author"),
		max_players = #hg_nodes.spawnpoint,
	}

	assert(map.width <= 549 and map.height <= 549 and map.length <= 549)
	assert(#hg_nodes.spawnpoint >= 1, "No spawnpoint on map " .. map.name)

	return map
end

do
	local files_hash = {}

	local dirs = minetest.get_dir_list(hg_map.mapdir, true)
	table.insert(dirs, ".")
	for _, dir in pairs(dirs) do
		local files = minetest.get_dir_list(hg_map.mapdir .. dir, false)
		for i=1, #files do
			local name = string.match(files[i], "(.*)%.conf")
			if name then
				files_hash[dir .. "/" .. name] = true
			end
		end
	end

	hg_map.available_maps = {}
	for key, _ in pairs(files_hash) do
		table.insert(hg_map.available_maps, hg_map.load_map_meta(#hg_map.available_maps + 1, key))
		if hg_map.available_maps[#hg_map.available_maps].name == "spawn" then
			hg_map.spawn = hg_map.available_maps[#hg_map.available_maps]
			table.remove(hg_map.available_maps)
		end
	end
	print(dump(hg_map.available_maps))
end

function hg_map.find_player_map(name)
	for _, map in ipairs(hg_map.maps) do
		for i, p_name in ipairs(map.players) do
			if p_name == name then
				return map, i
			end
		end
	end
end

function hg_map.get_map(spawnpoints_min)
	local selectable_maps = {}
	for _, map in ipairs(hg_map.maps) do
		if not map.in_use and map.ready and map.max_players >= spawnpoints_min then
			table.insert(selectable_maps, map)
		end
	end

	if #selectable_maps == 0 then
		return nil
	end

	return selectable_maps[math.random(#selectable_maps)]
end

function hg_map.update_map_offset(map)
	map.minp = map.offset
	map.maxp = vector.add(map.offset, { x = map.width + 2*map.margin, y = map.height, z = map.length + 2*map.margin })
	for k, positions in pairs(map.hg_nodes) do
		for i, pos in ipairs(positions) do
			map.hg_nodes[k][i] = vector.add(map.hg_nodes[k][i], vector.add(map.offset, {x = map.margin, y = 0, z = map.margin}))
		end
	end
end

--[[
local function update_offset(map)
	map.minp = vector.subtract(map.offset, { x = map.margin, y = 0, z = map.margin })
	map.maxp = vector.add(map.offset, { x = map.width + map.margin, y = map.height, z = map.length + map.margin })
	for k, positions in pairs(map.hg_nodes) do
		for i, pos in ipairs(positions) do
			map.hg_nodes[k][i] = vector.add(map.hg_nodes[k][i], map.offset)
		end
	end
end

function hg_map.get_map(map_meta, callback)
	-- Check for an available unused map.
	for i, map in ipairs(hg_map.maps) do
		-- Note: in_use is set by hg_match.
		if map.name == map_meta.name and not map.in_use then
			hg_map.place_map(map, callback) -- Clean the map from its previous game
			return
		end
	end

	-- We need to place a new map.
	-- Maps are placed on grid made of 1500x1500x1500 nodes chunks, starting at
	-- -30000,-30000,-30000 and ending at 28500,24000,28500. We can hence place
	-- a maximum of 40*37*40 = 59200 maps at the same time, which is big enough
	-- we don't have to worry about this limitation (make an assertion for fun,
	-- it would be really a pity not to know if the limit were reached, and
	-- it may more likely be caused by a bug).
	-- Because we want that players don't see nametag on players on other maps,
	-- we would have to limit the width of a map by 1500/(sqrt(2) + 1), that
	-- is, about 621 nodes, if we only considered dimensions X and Z.
	-- However, maps are 3-dimensional. If we want to take the height
	-- delta in account, the maximum width (and height) of maps is 1500/(sqrt(3)+1),
	-- about 549 nodes, which is reasonably large enough to allow quite large
	-- maps.
	-- Map margins are not included in these 549 nodes.
	-- Obviously, the `player_transfer_distance` setting must be also set to 549.

	local id = #hg_map.maps
	assert(id < 59200)

	local offset

	do

		local y = math.floor(id / (40*40)) * 1500 - 30000
		local y_remain = id % (40*40)
		local z = math.floor(y_remain / 40) * 1500 - 30000
		local z_remain = y_remain % 40
		local x = z_remain * 1500 - 30000
		offset = vector.new(x, y, z)
	end

	local map = table.copy(map_meta)
	map.offset = offset
	map.id = id + 1
	update_offset(map)
	table.insert(hg_map.maps, map)
	hg_map.emerge_and_place_map(map, callback)
end
]]

function hg_map.place_spawn()
	assert(hg_map.spawn, "Please add a spawn map.")

	hg_map.spawn.offset = vector.new(-hg_map.spawn.width/2, 24000, -hg_map.spawn.length/2)
	hg_map.update_map_offset(hg_map.spawn)

	hg_map.emerge_with_callbacks(nil, hg_map.spawn.minp, hg_map.spawn.maxp, function()
		local res = minetest.place_schematic(hg_map.spawn.minp, hg_map.spawn.path .. ".mts", "0")
	end, nil)
end

minetest.after(0, hg_map.place_spawn)

--[[
function hg_map.place_map(map, callback)
	minetest.chat_send_all(minetest.colorize("#ff0000", "A map schematic is being imported for a future game... (This typically takes about 20 seconds)"))

	-- Place map itself
	local schempath = hg_map.mapdir .. map.schematic
	local start_time = os.time()
	local res = minetest.place_schematic(map.minp, schempath, "0")

	minetest.chat_send_all(minetest.colorize("#ff0000",
		string.format("Finished importing in %d seconds. Thank you for your patience!", os.time() - start_time)))

	assert(res)

	-- Clear objects (563 is the maximum distance between the center
	-- and a corner of the map, 50-nodes margin included)
	minetest.after(0.5, function()
		local center = vector.add(map.offset, vector.round(vector.new(map.width / 2, map.height / 2, map.length / 2)))
		local objects = minetest.get_objects_inside_radius(center, 563)
		for _, object in ipairs(objects) do
			if not object:is_player() then
				object:remove()
			end
		end
	end)

	-- Fill chests
	-- Split the global chests stuff at random intervals and dispatch
	-- it in the chests.
	local chests = map.hg_nodes.chest

	local splitted_stuff = {}
	for k, v in pairs(chests_stuff) do
		splitted_stuff[k] = {}
		local splitpoints = {}
		for i = 1, #chests-1 do
			table.insert(splitpoints, math.random(v))
		end
		table.sort(splitpoints)
		splitted_stuff[k][1] = splitpoints[1] or 0 -- the or avoids crashing if there is only one chest
		for i = 2, #chests-1 do
			splitted_stuff[k][i] = splitpoints[i] - splitpoints[i-1]
		end
		splitted_stuff[k][#chests] = v - (splitpoints[#chests-1] or 0)
	end

	for i, pos in ipairs(chests) do
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("main", 8*4)
		inv:set_list("main", {})
		for name, quantity in pairs(splitted_stuff) do
			local stack = ItemStack(name)
			stack:set_count(quantity[i])
			inv:add_item("main", stack)
		end
	end

	-- Finally, let the callback take the torch
	callback(map)
end

function hg_map.emerge_and_place_map(map, callback)
	minetest.chat_send_all(minetest.colorize("#ff0000", "A map is currently being emerged. The server may be unresponsive for up to a few minutes."))
	local previous_percentage = 0

	hg_map.emerge_with_callbacks(nil, map.minp, map.maxp, function()
		hg_map.place_map(map, callback)
	end, function(ctx)
		local percentage = (ctx.current_blocks / ctx.total_blocks) * 10

		if previous_percentage < math.floor(percentage) then
			previous_percentage = math.floor(percentage)
			minetest.chat_send_all(minetest.colorize("#ff0000", string.format("Emerged %d%%...", percentage * 10)))
		end
	end)
end
]]

function hg_map.chat_send_map(map, message)
	for _, name in ipairs(map.players) do
		minetest.chat_send_player(name, message)
	end
end

dofile(minetest.get_modpath("hg_map") .. "/map_placer.lua")
