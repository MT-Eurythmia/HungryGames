minetest.override_item("bucket:bucket_water", {
	on_use = function(itemstack, user, pointed_thing)
		return hg_hunger.item_drink(6, itemstack, user, "bucket:bucket_empty")
	end,
})

local alt_water_sources = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
};

minetest.override_item("vessels:drinking_glass", {
	liquids_pointable = true,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		local node = minetest.get_node(pointed_thing.under)
		if alt_water_sources[node.name] then
			local newitem = ItemStack("hg_hunger:water_glass 1");
			local inv = user:get_inventory();
			if inv:room_for_item("main", newitem) then
				inv:add_item("main", newitem)
				if not minetest.registered_items[node.name].liquidtype == "none" then
					minetest.remove_node(pointed_thing.under)
				end
				itemstack:take_item()
				return itemstack
			end
		end
	end,
})

minetest.register_craftitem("hg_hunger:water_glass", {
	description = "Glass of Water",
	inventory_image = "hg_hunger_water_glass.png",
	groups = {},
	on_use = function(itemstack, user, pointed_thing)
		return hg_hunger.item_drink(2, itemstack, user, "vessels:drinking_glass")
	end,
})
