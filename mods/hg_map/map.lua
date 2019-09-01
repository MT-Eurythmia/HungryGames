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
	["default:cobble"]  = 350,
	["default:wood"]    = 350,
	["3d_armor:helmet_wood"]        = 50,
	["3d_armor:chestplate_wood"]    = 50,
	["3d_armor:leggings_wood"]      = 50,
	["3d_armor:boots_wood"]         = 50,
	["shields:shield_wood"]         = 50,
	["3d_armor:helmet_steel"]       = 30,
	["3d_armor:chestplate_steel"]   = 30,
	["3d_armor:leggings_steel"]     = 30,
	["3d_armor:boots_steel"]        = 30,
	["shields:shield_steel"]        = 30,
	["3d_armor:helmet_bronze"]      = 15,
	["3d_armor:chestplate_bronze"]  = 15,
	["3d_armor:leggings_bronze"]    = 15,
	["3d_armor:boots_bronze"]       = 15,
	["shields:shield_bronze"]       = 15,
	["3d_armor:helmet_gold"]        = 7,
	["3d_armor:chestplate_gold"]    = 7,
	["3d_armor:leggings_gold"]      = 7,
	["3d_armor:boots_gold"]         = 7,
	["shields:shield_gold"]         = 7,
	["3d_armor:helmet_diamond"]     = 1,
	["3d_armor:chestplate_diamond"] = 1,
	["3d_armor:leggings_diamond"]   = 1,
	["3d_armor:boots_diamond"]      = 1,
	["shields:shield_diamond"]      = 1,
	["default:sword_wood"]    = 100,
	["default:sword_steel"]   = 50,
	["default:sword_bronze"]  = 37,
	["default:sword_mese"]    = 5,
	["default:sword_diamond"] = 1,
	["throwing:arrow"]      = 200,
	["throwing:arrow_gold"] = 70,
	["throwing:arrow_diamond"] = 20,
	["throwing:bow_wood"]   = 30,
	["throwing:bow_steel"]  = 7,
	["farming:cotton"]      = 70,
	["default:steel_ingot"]  = 100,
	["default:bronze_ingot"] = 50,
	["default:gold_ingot"]   = 30,
	["default:diamond"]      = 15,
	["default:mese_crystal"] = 20,
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

	assert(hg_map.spawn, "Please add a spawn map.")
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
		if map.ready and map.max_players >= spawnpoints_min then
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

function hg_map.chat_send_map(map, message)
	for _, name in ipairs(map.players) do
		minetest.chat_send_player(name, message)
	end
end

function hg_map.clear_objects_map(map)
	local center = vector.add(map.offset,
		vector.round(vector.new(map.width / 2 + map.margin, map.height / 2, map.length / 2 + map.margin)))
	local radius = math.ceil(math.sqrt(math.pow(map.width / 2 + map.margin, 2)
			+ math.pow(map.height / 2, 2)
			+ math.pow(map.length / 2 + map.margin, 2)))
	local objects = minetest.get_objects_inside_radius(center, radius)
	for _, object in ipairs(objects) do
		if not object:is_player() then
			object:remove()
		end
	end
end

minetest.register_on_prejoinplayer(function(name, ip)
	if not hg_map.spawn.ready then
		return "Sorry, the map is not ready yet. Try again in a few minutes!"
	end
end)

dofile(minetest.get_modpath("hg_map") .. "/map_placer.lua")
