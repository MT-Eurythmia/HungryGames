-- Relatively light coroutine that continuously runs to prepare maps during games.
-- minetest.place_schematic causes the whole server to become unresponsive for
-- server minutes, which is impractical.
-- Here we need maximum effiency to slow down the server as little as possible.
-- Schematics are placed block by block (16x16x16 nodes) every 0.3 second.

--[[
local IGNORE_ID = minetest.get_content_id("hg_map:ignore")
local PLACE_BLOCK_SIZE = 3 -- place block size in mapblocks (16 * 16 * 16)

local function place_one_schematic(map, part_index, minp, maxp)
do
	-- Load the schematic in memory.
	local schempath = string.format("%s_%d.mts", map.path, part_index)
	print("Starting read_schematic on map "..map.name.." part #"..part_index.."...")
	local schematic = minetest.read_schematic(schempath, {
		write_yslice_prob = "none",
	})
	print("End of read_schematic.")
	coroutine.yield()

	-- We're placing the schematic block by block
	local schematic_varea = VoxelArea:new{MinEdge = minp, MaxEdge = maxp}

	local sblockx_start, sblockx_end, sblocky_start, sblocky_end, sblockz_start, sblockz_end =
		math.floor(minp.x / 16), math.floor(maxp.x / 16),
		math.floor(minp.y / 16), math.floor(maxp.y / 16),
		math.floor(minp.z / 16), math.floor(maxp.z / 16)
	local blockx_start, blockx_end, blocky_start, blocky_end, blockz_start, blockz_end =
		math.floor(sblockx_start / PLACE_BLOCK_SIZE), math.floor(sblockx_end / PLACE_BLOCK_SIZE),
		math.floor(sblocky_start / PLACE_BLOCK_SIZE), math.floor(sblocky_end / PLACE_BLOCK_SIZE),
		math.floor(sblockz_start / PLACE_BLOCK_SIZE), math.floor(sblockz_end / PLACE_BLOCK_SIZE)

	local total_blocks = (blockx_end - blockx_start + 1) * (blocky_end - blocky_start + 1) * (blockz_end - blockz_start + 1)
	minetest.log("action", string.format("[hg_map] Starting loading of map id %d part %d at position %s with schematic %s. Number of blocks: %d",
		map.id, part_index, minetest.pos_to_string(minp), map.name, total_blocks))

	local n = 0
	for blockx = blockx_start, blockx_end do
	for blocky = blocky_start, blocky_end do
	for blockz = blockz_start, blockz_end do
		local start_time = os.clock()
		collectgarbage()
		local blockpos_min = {x = PLACE_BLOCK_SIZE * 16 * blockx, y = PLACE_BLOCK_SIZE * 16 * blocky, z = PLACE_BLOCK_SIZE * 16 * blockz}
		local blockpos_max = {
			x = math.min(blockpos_min.x + PLACE_BLOCK_SIZE * 16 - 1, 16 * sblockx_end),
			y = math.min(blockpos_min.y + PLACE_BLOCK_SIZE * 16 - 1, 16 * sblocky_end),
			z = math.min(blockpos_min.z + PLACE_BLOCK_SIZE * 16 - 1, 16 * sblockz_end),
		}
		local vmanip = minetest.get_voxel_manip(blockpos_min, blockpos_max)
		local vminp, vmaxp = vmanip:get_emerged_area()
		print(minetest.pos_to_string(vminp), minetest.pos_to_string(vmaxp))
		local vmanip_data = vmanip:get_data()
		local vmanip_param2_data = vmanip:get_param2_data()

		local vmanip_i = 1
		for x = vminp.z, vmaxp.z do
		for y = vminp.y, vmaxp.y do
		for z = vminp.x, vmaxp.x do
			if schematic_varea:contains(x, y, z) then
				local schem_i = schematic_varea:index(x, y, z)
				local nodedata = schematic.data[schem_i]
				vmanip_data[vmanip_i] = minetest.get_content_id(nodedata.name)
				vmanip_param2_data[vmanip_i] = nodedata.param2
			 end

			vmanip_i = vmanip_i + 1
		end
		end
		end

		vmanip:set_data(vmanip_data)
		vmanip:set_param2_data(vmanip_param2_data)
		vmanip:write_to_map(false) -- False indicates not to fix lighting -- lighting is already good

		n = n + 1
		if n % 5 == 0 then
			minetest.log("action", string.format("[hg_map] Loaded %d blocks for map %d part %d (%f%%) in %d seconds.",
				n, map.id, part_index, n / total_blocks * 100, os.clock() - start_time))
		end

		coroutine.yield()
	end
	end
	end

	minetest.log("action", "Finished map loading of map id " .. map.id .. " part " .. part_index .. ".")
end
collectgarbage() -- Make sure to discard the schematic part
end
]]

local function coroutine_body()
	while true do
		-- Let's select a map to prepare.
		local map
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

		local _, map = next(nonready_maps)
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

				-- Emerge
				local emerging = true
				hg_map.emerge_with_callbacks(nil, new_map.minp, new_map.maxp, function()
					emerging = false
				end, nil)

				while emerging do
					coroutine.yield()
				end

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
			for k, v in pairs(hg_map.chests_stuff) do
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

			-- Fix light
			--print(minetest.fix_light(map.minp, map.maxp))

			minetest.log("action", string.format("[hg_map] Finished loading of map id %d.", map.id))

			map.ready = true
			if hg_match.waiting_map_flag then
				hg_match.waiting_map_flag = false
				hg_match.new_game()
			end
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
