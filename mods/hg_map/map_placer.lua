-- Relatively light coroutine that continuously runs to prepare maps during games.
-- minetest.place_schematic causes the whole server to become unresponsive for
-- server minutes, which is impractical.
-- Here we need maximum effiency to slow down the server as little as possible.
-- Schematics are placed block by block (16x16x16 nodes) every 0.3 second.

local function emerge(minp, maxp)
	local emerging = true
	hg_map.emerge_with_callbacks(nil, minp, maxp, function()
		emerging = false
	end, nil)

	while emerging do
		coroutine.yield()
	end
end

local function finalize_map(map)
	-- Clear objects
	minetest.after(0.5, function()
		hg_map.clear_objects_map(map)
	end)

	-- Fill chests
	-- Split the global chests stuff at random intervals and dispatch
	-- it in the chests.
	local chests = map.hg_nodes.chest

	local splitted_stuff = {}
	for k, v in pairs(hg_map.chests_stuff) do
		splitted_stuff[k] = {}
		local splitpoints = {}
		for i = 1, #chests-1 do
			table.insert(splitpoints, math.random(0, v))
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
end

local function coroutine_body()
	while true do
		-- Let's select a map to prepare.
		local map
		if not hg_map.spawn.ready then
			-- If we don't have a spawn yet, start with it
			map = hg_map.spawn
			map.id = -1
			map.offset = vector.new(24000, 24000, 24000)
			hg_map.update_map_offset(map)
			emerge(map.minp, map.maxp)
		else
			local nonready_maps = {}
			for _, map in ipairs(hg_map.available_maps) do
				nonready_maps[map.name] = map
			end
			for _, map in ipairs(hg_map.maps) do
				if not map.in_use then
					if not map.ready then
						nonready_maps[map.name] = map
					else
						nonready_maps[map.name] = nil
					end
				end
			end
			local _, selected_map = next(nonready_maps)
			map = selected_map
		end

		if map then
			if not map.offset then
				-- Compute the offset
				local id = #hg_map.maps
				assert(id < 59200)

				local offset

				do
					-- Note: the offset coordonates should be divisible by 64.
					local y = math.floor(id / (40*40)) * 1600 - 30016
					local y_remain = id % (40*40)
					local z = math.floor(y_remain / 40) * 1600 - 30016
					local z_remain = y_remain % 40
					local x = z_remain * 1600 - 30016
					offset = vector.new(x, y, z)
				end

				local new_map = table.copy(map)
				new_map.offset = offset
				new_map.id = id + 1
				hg_map.update_map_offset(new_map)
				new_map.players = {}
				new_map.ready = false
				table.insert(hg_map.maps, new_map)

				emerge(new_map.minp, new_map.maxp)

				map = new_map
			end

			-- Compute the number of schematics
			local total_schems = math.ceil((map.width + 2 * map.margin) / map.blocksize)
				* math.ceil((map.length + 2 * map.margin) / map.blocksize)
				* math.ceil(map.height / map.blocksize)


			minetest.log("action", string.format("[hg_map] Starting loading of map id %d containing %d parts at position %s with schematic %s.",
				map.id, total_schems, minetest.pos_to_string(map.minp), map.name))

			-- Place the schematics one by one
			local part_id = 1
			for z = map.minp.z, map.maxp.z, map.blocksize do
			for y = map.minp.y, map.maxp.y, map.blocksize do
			for x = map.minp.x, map.maxp.x, map.blocksize do
				local sub_minp = {x = x, y = y, z = z}
				local sub_maxp = {
					x = math.min(x + map.blocksize - 1, map.maxp.x),
					y = math.min(y + map.blocksize - 1, map.maxp.y),
					z = math.min(z + map.blocksize - 1, map.maxp.z)
				}
				local vmanip = minetest.get_voxel_manip(sub_minp, sub_maxp)
				local schempath = string.format("%s_%d.mts", map.path, part_id)
				minetest.place_schematic_on_vmanip(vmanip, sub_minp, schempath, "0", {}, true)
				-- minetest.fix_light does not seem to work in parts not loaded by players,
				-- so set light to 255 everywhere instead.
				local light_data = {}
				for i = 1, (sub_maxp.x - sub_minp.x) * (sub_maxp.y - sub_minp.y) * (sub_maxp.z - sub_minp.z) do
					light_data[i] = 255
				end
				vmanip:set_light_data(light_data)
				vmanip:write_to_map(false)

				part_id = part_id + 1
				coroutine.yield()
			end
			end
			end

			-- The whole schematic is now loaded.
			-- Finalization

			if map.name ~= "spawn" then
				finalize_map(map)
			end

			minetest.log("action", string.format("[hg_map] Finished loading of map id %d.", map.id))

			map.ready = true
		else
			-- There is no need for a map.
			coroutine.yield()
		end
	end
end

local loader_coroutine = coroutine.create(function()
	local ok, err = pcall(coroutine_body)
	if not ok then
		minetest.log("error", "[hg_map] Map loading coroutine failed with error: " .. err)
	end
end)

local counter = 0
minetest.register_globalstep(function(dtime)
	counter = counter + dtime
	if counter < 0.5 then
		return
	end

	counter = counter - 0.5

	if coroutine.status(loader_coroutine) == "dead" then
		error("Map loading coroutine exited.")
	end
	coroutine.resume(loader_coroutine)
end)
