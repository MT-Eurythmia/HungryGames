-- Waiting HUD
hg_player.text_huds = {}

function hg_player.update_text_hud(player, text)
	local name = player:get_player_name()
	if not name then
		return false
	end

	local id = hg_player.text_huds[name]
	if not id then
		-- Create
		hg_player.text_huds[name] = player:hud_add({
			hud_elem_type = "text",
			position      = {x = 0.5, y = 0.7},
			offset        = {x = 0, y = 0},
			text          = text,
			alignment     = 0,
			scale         = {x = 100, y = 20},
			number        = 0xFFFFFF,
		})
	else
		-- Update
		player:hud_change(id, "text", text)
		-- I don't know why the following is necessary, but otherwise
		-- it turns black
		player:hud_change(id, "number", 0xFFFFFF)
	end
end

function hg_player.update_text_hud_all(names, text)
	for _, name in ipairs(names) do
		hg_player.update_text_hud(minetest.get_player_by_name(name), text)
	end
end

function hg_player.remove_text_hud(player)
	local name = player:get_player_name()
	local id = hg_player.text_huds[name]
	if id then
		player:hud_remove(id)
		hg_player.text_huds[name] = nil
	end
end

minetest.register_on_leaveplayer(function(player)
	hg_player.remove_text_hud(player)
end)
