-- Chest --

if not minetest.is_singleplayer() then
	local old_on_metadata_inventory_take = {
		minetest.registered_items["default:chest"].on_metadata_inventory_take,
		minetest.registered_items["default:chest_open"].on_metadata_inventory_take,
	}
	for i, name in ipairs({"default:chest", "default:chest_open"}) do
		minetest.override_item(name, {
			on_metadata_inventory_take = function(pos, from_list, from_index, to_list, to_index, count, player)
				local inv = minetest.get_inventory({
					type = "node",
					pos = pos
				})

				if inv:is_empty("main") then
					minetest.remove_node(pos)
				end

				return old_on_metadata_inventory_take[i]
			end,
			groups = {not_in_creative_inventory = 1}, -- Make it unbreakable.
		})
	end

	-- Useful hack
	local old_minetest_swap_node = minetest.swap_node
	function minetest.swap_node(pos, node)
		local prev_node = minetest.get_node(pos)
		if node.name == "default:chest" and prev_node.name == "air" then
			return
		end
		return old_minetest_swap_node(pos, node)
	end

	minetest.clear_craft({output = "default:chest"})
end

-- Spawnpoint --

minetest.register_node("hg_map:spawnpoint", {
	description = "Spawn Point",
	tiles = {"default_gold_block.png"},
	is_ground_content = false,
	groups = {},
	sounds = default.node_sound_metal_defaults(),
})

if minetest.is_singleplayer() then
	minetest.override_item("hg_map:spawnpoint", {
		groups = {cracky = 1, level = 2},
	})
else
	minetest.override_item("hg_map:spawnpoint", {
		groups = {not_in_creative_inventory = 1},
	})
end

-- Ignore --

minetest.register_node("hg_map:ignore", {
	description = "HG Ignore",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable     = true,
	pointable    = false,
	diggable     = false,
	buildable_to = false,
	air_equivalent = true,
	drop = "",
	groups = {not_in_creative_inventory=1},
	on_blast = function(pos, intensity) end,
})

-- Indestructible glass --

minetest.register_node("hg_map:ind_glass", {
	description = "Indestructible Glass",
	drawtype = "glasslike_framed_optional",
	tiles = {"default_glass.png", "default_glass_detail.png"},
	inventory_image = minetest.inventorycube("default_glass.png"),
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = true,
	buildable_to = false,
	pointable = false,
	groups = {immortal = 1},
	sounds = default.node_sound_glass_defaults(),
	on_blast = function(pos, intensity) end,
})

-- Indestructible stone --

minetest.register_node("hg_map:ind_stone", {
	description = "Indestructible Stone",
	groups = {immortal = 1},
	tiles = {"default_stone.png"},
	is_ground_content = false,
	on_blast = function(pos, intensity) end,
})
