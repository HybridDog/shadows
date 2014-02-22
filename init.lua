local function table_contains(v, t)
	for _,i in ipairs(t) do
		if i==v then
			return true
		end
	end
	return false
end

minetest.register_node("shadows:shadow", {
	tiles = {"shadows.png"},
	walkable = false
})

minetest.register_abm({
	nodenames = {"air"},
	neighbors = {"default:dirt_with_grass", "default:dirt"},
	interval = 2,
	chance = 1,
	action = function(pos)
		local dir = vector.sun_dir(minetest.get_timeofday())
		if not dir then
			return
		end
		for _,i in ipairs(vector.line(pos, dir, 50)) do
			if not table_contains(minetest.get_node(i).name, {"air", "ignore", "shadows:shadow"}) then
				minetest.set_node(pos, {name = "shadows:shadow"})
				return
			end
		end
	end,
})

minetest.register_abm({
	nodenames = {"shadows:shadow"},
	interval = 2,
	chance = 1,
	action = function(pos)
		local dir = vector.sun_dir(minetest.get_timeofday())
		if not dir then
			return
		end
		for _,i in ipairs(vector.line(pos, dir, 50)) do
			if not table_contains(minetest.get_node(i).name, {"air", "ignore", "shadows:shadow"}) then
				return
			end
		end
		minetest.remove_node(pos)
	end,
})
