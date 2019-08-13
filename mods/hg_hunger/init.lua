if minetest.is_singleplayer() then
	return
end

hg_hunger = {}

function hg_hunger.start_hunger(player)
	local meta = player:get_meta()
	meta:set_int("hunger", 20)
	meta:set_int("thirst", 20)

	meta:set_int("hunger_bar_id", player:hud_add({
		hud_elem_type = "statbar",
		position = { x=0.5, y=1 },
		text = "farming_bread.png",
		direction = 0,
		number = 20,
		size = { x=24, y=24 },
		offset = {x=(-10*24)-25,y=-(48+2*(24+16))},
	}))

	meta:set_int("thirst_bar_id", player:hud_add({
		hud_elem_type = "statbar",
		position = { x=0.5, y=1 },
		text = "hg_hunger_water_glass.png",
		direction = 0,
		number = 20,
		size = { x=24, y=24 },
		offset = {x=25,y=-(48+2*(24+16))},
	}))
end

function hg_hunger.stop_hunger(player)
	local meta = player:get_meta()

	for _, attr in ipairs({"hunger", "thirst"}) do
		meta:set_string(attr, "")
		local hud_id = meta:get(attr .. "_bar_id")
		if hud_id then
			player:hud_remove(tonumber(hud_id))
			meta:set_string(attr .. "_bar_id", "") -- This removes the key
		end
	end
end

function hg_hunger.alter_hunger(player, attribute, value)
	local meta = player:get_meta()

	local hunger_v = meta:get(attribute)
	if not hunger_v then
		return
	end
	hunger_v = tonumber(hunger_v)

	local new_v = math.min(hunger_v + value, 20)
	if new_v > 0 then
		meta:set_int(attribute, new_v)
		player:hud_change(meta:get_int(attribute .. "_bar_id"), "number", new_v)
	elseif hunger_v ~= 0 then
		meta:set_int(attribute, 0)
		player:hud_change(meta:get_int(attribute .. "_bar_id"), "number", 0)
	end
end

do
	local timer = 0
	local thirst_counter = 0
	local hunger_counter = 0
	local heal_counter = 0
	local damage_counter = 0
	minetest.register_globalstep(function(dtime)
		timer = timer + dtime
		if timer < 1 then
			return
		end

		timer = timer - 1

		local players = minetest.get_connected_players()

		thirst_counter = thirst_counter + 1
		if thirst_counter >= 20 then
			thirst_counter = 0
			for _, player in ipairs(players) do
				hg_hunger.alter_hunger(player, "thirst", -1)
			end
		end

		hunger_counter = hunger_counter + 1
		if hunger_counter >= 35 then
			hunger_counter = 0
			for _, player in ipairs(players) do
				hg_hunger.alter_hunger(player, "hunger", -1)
			end
		end

		heal_counter = heal_counter + 1
		if heal_counter >= 10 then
			heal_counter = 0
			for _, player in ipairs(players) do
				local meta = player:get_meta()
				local hunger_v = meta:get("hunger")
				if hunger_v then
					local hp = player:get_hp()
					if tonumber(hunger_v) >= 17 and hp < 20 then
						player:set_hp(hp + 1)
					end
				end
			end
		end

		damage_counter = damage_counter + 1
		if damage_counter >= 4 then
			damage_counter = 0
			for _, player in ipairs(players) do
				local meta = player:get_meta()

				local hunger_v = meta:get("hunger")
				local thirst_v = meta:get("thirst")

				if hunger_v and tonumber(hunger_v) <= 0 then
					player:set_hp(player:get_hp() - 2)
				end
				if thirst_v and tonumber(thirst_v) <= 0 then
					player:set_hp(player:get_hp() - 2)
				end
			end
		end
	end)
end

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, player, pointed_thing)
	local meta = player:get_meta()

	if not meta:get("hunger") then
		return itemstack
	end

	hg_hunger.alter_hunger(player, "hunger", hp_change)

	itemstack:take_item(1)
	return itemstack
end)

function hg_hunger.item_drink(value, itemstack, player, replace_with_item)
	local meta = player:get_meta()

	if not meta:get("thirst") then
		return itemstack
	end

	hg_hunger.alter_hunger(player, "thirst", value)

	itemstack:take_item(1)

	local stack = ItemStack(replace_with_item)
	local inv = player:get_inventory()
	if inv:room_for_item("main", stack) then
		inv:add_item("main", stack)
	end
	return itemstack
end

dofile(minetest.get_modpath("hg_hunger") .. "/drink_nodes.lua")
