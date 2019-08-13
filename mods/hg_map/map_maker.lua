assert(worldedit, "Please load WorldEdit to use the map maker tool.")

-- This storage is only useful when using the map maker tool. It can
-- be safely deleted when using in production.
local storage = minetest.get_mod_storage()
local absolute_nodes = minetest.deserialize(storage:get_string("nodes")) or {}
local relative_nodes = {}

local map_limits

minetest.register_on_joinplayer(function(player)
	minetest.after(1, function()
		minetest.chat_send_player("singleplayer", "Detected singleplayer game: you are in map maker mode.")
	end)
end)

function vector.within(v, minp, maxp)
	if v.x > minp.x and v.y > minp.y and v.z > minp.z
		and v.x < maxp.x and v.y < maxp.y and v.z < maxp.z then
		return true
	else
		return false
	end
end

local function relativize_relative_things()
	if not (worldedit.pos1["singleplayer"] and worldedit.pos2["singleplayer"]) then
		minetest.chat_send_player("singleplayer", "Please select a WorldEdit region.")
		return false
	end

	local minp, maxp = vector.sort(worldedit.pos1["singleplayer"], worldedit.pos2["singleplayer"])

	if maxp.x - minp.x > 549 or maxp.y - minp.y > 549 or maxp.z - minp.z > 549 then
		minetest.chat_send_payer("singleplayer", "The map dimensions cannot exceed 549 nodes.")
		return false
	end

	for name, positions in pairs(absolute_nodes) do
		for i, pos in ipairs(absolute_nodes[name]) do
			if not vector.within(pos, minp, maxp) then
				minetest.chat_send_player("singleplayer", "Warning: removing " .. name .. " at position " ..
					minetest.pos_to_string(pos) .. " because it is outside the selected WorldEdit region.")
				minetest.remove_node(pos)
			else
				if not relative_nodes[name] then
					relative_nodes[name] = {}
				end
				table.insert(relative_nodes[name], vector.subtract(absolute_nodes[name][i], minp))
				minetest.chat_send_player("singleplayer", "Successfully relativized " .. name .. " at " .. minetest.pos_to_string(pos))
			end
		end
	end

	map_limits = {minp, maxp}

	return true
end

local function add_something_relative(name, pos)
	if not absolute_nodes[name] then
		absolute_nodes[name] = {}
	end

	for _, v in ipairs(absolute_nodes[name]) do
		if vector.equals(v, pos) then
			return
		end
	end

	table.insert(absolute_nodes[name], pos)
	storage:set_string("nodes", minetest.serialize(absolute_nodes))
end

local function delete_something_relative(name, pos)
	local positions = absolute_nodes[name]
	for i, v in ipairs(positions) do
		if vector.equals(v, pos) then
			table.remove(absolute_nodes[name], i)
			storage:set_string("nodes", minetest.serialize(absolute_nodes))
		end
	end
end

-- Chest --

local old_on_construct = minetest.registered_items["default:chest"].on_construct or function() end
local old_on_destruct = minetest.registered_items["default:chest"].on_destruct or function() end
minetest.override_item("default:chest", {
	on_construct = function(pos)
		add_something_relative("chest", pos)
		return old_on_construct(pos)
	end,
	on_destruct = function(pos)
		delete_something_relative("chest", pos)
		return old_on_destruct(pos)
	end,
})

-- Spawnpoint --

minetest.override_item("hg_map:spawnpoint", {
	on_construct = function(pos)
		add_something_relative("spawnpoint", pos)
	end,
	on_destruct = function(pos)
		delete_something_relative("spawnpoint", pos)
	end,
})

minetest.register_lbm({
	label = "Register Hungry Games nodes",
	name = "hg_map:register_hg_nodes",
	nodenames = {"default:chest", "hg_map:spawnpoint"},
	run_at_every_load = false,
	action = function(pos, node)
		local name = node.name
		if name == "default:chest" then
			add_something_relative("chest", pos)
		elseif name == "hg_map:spawnpoint" then
			add_something_relative("spawnpoint", pos)
		end
	end,
})

-- Exportator --

-- Thanks @rubenwardy
local function show_progress_formspec(name, text)
	minetest.show_formspec(name, "hg_map:progress",
		"size[6,1]bgcolor[#080808BB;true]" ..
		default.gui_bg ..
		default.gui_bg_img .. "label[0,0;" ..
		minetest.formspec_escape(text) .. "]")
end

local function emerge_progress(ctx)
	show_progress_formspec("singleplayer", string.format("Emerging Area - %d/%d blocks emerged (%.1f%%)",
		ctx.current_blocks, ctx.total_blocks,
		(ctx.current_blocks / ctx.total_blocks) * 100))
end

minetest.register_chatcommand("hg_relativize", {
	params = "",
	description = "Prepare a map for exporting",
	func = function(player_name, param)
		if relativize_relative_things() then
			return true, "Successful relativization! You can now type /hg_export."
		end
	end
})

local function continue_export_after_emerge(player_name, param, minp, maxp)
	local BLOCKSIZE = 64

	show_progress_formspec(player_name, "Placing barriers...")
	hg_map.place_outer_barrier(map_limits[1], map_limits[2])

	show_progress_formspec(player_name, "Exporting...")

	local path = minetest.get_worldpath() .. "/schems/"
	minetest.mkdir(path)

	local meta = Settings(path .. param .. ".conf")
	meta:set("width", map_limits[2].x - map_limits[1].x)
	meta:set("length", map_limits[2].z - map_limits[1].z)
	meta:set("height", map_limits[2].y - map_limits[1].y)
	meta:set("hg_nodes", minetest.serialize(relative_nodes))
	meta:set("margin", 50)
	meta:set("blocksize", BLOCKSIZE)
	meta:write()

	minetest.after(0.1, function()
		-- A schematic is created for each block (a block is 256x256x256 nodes big).
		-- Schematic are indexed in the [z [y [x]]] order.
		local basepath = path .. param .. ".mts"
		local total_blocks = math.ceil((maxp.x - minp.x + 1) / BLOCKSIZE)
			* math.ceil((maxp.y - minp.y + 1) / BLOCKSIZE)
			* math.ceil((maxp.z - minp.z + 1) / BLOCKSIZE)
		local index = 1
		for z = minp.z, maxp.z, BLOCKSIZE do
		for y = minp.y, maxp.y, BLOCKSIZE do
		for x = minp.x, maxp.x, BLOCKSIZE do
			local sub_minp = {x = x, y = y, z = z}
			local sub_maxp = {
				x = math.min(x + BLOCKSIZE - 1, maxp.x),
				y = math.min(y + BLOCKSIZE - 1, maxp.y),
				z = math.min(z + BLOCKSIZE - 1, maxp.z)
			}
			local filepath = string.format("%s%s_%d.mts", path, param, index)
			if minetest.create_schematic(sub_minp, sub_maxp, {}, filepath) then
				show_progress_formspec(player_name, string.format("Exported %d blocks out of %d...", index, total_blocks))
			else
				minetest.chat_send_all("Failed!")
				minetest.close_formspec(player_name, "")
				return
			end
			index = index + 1
		end
		end
		end
		minetest.chat_send_all("Exported " .. param .. " to " .. path)
		minetest.close_formspec(player_name, "")
	end)
end

minetest.register_chatcommand("hg_export", {
	params = "[<name>]",
	description = "Export a Hungry Game worldedit-selected map. Name defaults to 'hungrygames'",
	func = function(player_name, param)
		if not map_limits or not map_limits[1] or not map_limits[2] then
			minetest.chat_send_player(player_name, "Please select a WorldEdit region and type /hg_relativize.")
			return false
		end
		if param == "" then
			param = "hungrygames"
		end
		-- Add a 50-nodes margin
		local minp = vector.subtract(map_limits[1], { x = 50, y = 0, z = 50 })
		local maxp = vector.add(map_limits[2], { x = 50, y = 0, z = 50 })

		show_progress_formspec(player_name, "Emerging area...")
		hg_map.emerge_with_callbacks(player_name, minp, maxp, function()
			continue_export_after_emerge(player_name, param, minp, maxp)
		end, emerge_progress)
		return true
	end
})
