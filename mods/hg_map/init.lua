hg_map = {}

local modpath = minetest.get_modpath("hg_map")

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/emerge.lua")
dofile(modpath .. "/barrier.lua")

if minetest.is_singleplayer() then
	dofile(modpath .. "/map_maker.lua")
else
	dofile(modpath .. "/map.lua")
end
