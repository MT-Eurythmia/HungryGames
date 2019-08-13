-- The following code is almost copy-pasted from the CaptureTheFlag subgame
-- by Rubenwardy.

local c_stone      = minetest.get_content_id("hg_map:ind_stone")
local c_glass      = minetest.get_content_id("hg_map:ind_glass")
local c_map_ignore = minetest.get_content_id("hg_map:ignore")
local c_air        = minetest.get_content_id("air")

function hg_map.place_outer_barrier(minp, maxp)
	print("Loading data into LVM")

	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local data = vm:get_data()

	print("Placing left wall")

	-- Left
	local x = minp.x
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = a:index(x, y, z)
			if data[vi] == c_air or data[vi] == c_glass or data[vi] == c_map_ignore then
				data[vi] = c_glass
			else
				data[vi] = c_stone
			end
		end
	end

	print("Placing right wall")

	-- Right
	local x = maxp.x
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = a:index(x, y, z)
			if data[vi] == c_air or data[vi] == c_glass or data[vi] == c_map_ignore then
				data[vi] = c_glass
			else
				data[vi] = c_stone
			end
		end
	end

	print("Placing front wall")

	-- Front
	local z = minp.z
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			local vi = a:index(x, y, z)
			if data[vi] == c_air or data[vi] == c_glass or data[vi] == c_map_ignore then
				data[vi] = c_glass
			else
				data[vi] = c_stone
			end
		end
	end

	print("Placing back wall")

	-- Back
	local z = maxp.z
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			local vi = a:index(x, y, z)
			if data[vi] == c_air or data[vi] == c_glass or data[vi] == c_map_ignore then
				data[vi] = c_glass
			else
				data[vi] = c_stone
			end
		end
	end

	print("Writing to engine!")

	vm:set_data(data)
	vm:write_to_map(data)
	vm:update_map()
end
