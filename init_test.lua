--[[local function table_contains(v, t)
	for _,i in ipairs(t) do
		if i==v then
			return true
		end
	end
	return false
end

local function set_shadow(pos, light)
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(pos, pos)
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()
	manip:set_data(nodes)
	manip:set_lighting(light)
	manip:write_to_map()
	manip:update_map()
end

local function calc_light(pos)
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(pos, pos)
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()
	manip:set_data(nodes)
	manip:calc_lighting()
	manip:write_to_map()
	manip:update_map()
end

--[minetest.register_node("shadows:shadow", {
	tiles = {"shadows.png"},
	walkable = false
})
minetest.register_abm({
	nodenames = {"shadows:shadow"},
	interval = 2,
	chance = 1,
	action = function(pos)
		minetest.remove_node(pos)
	end,
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
		local light = minetest.get_node_light(pos)
		for _,i in ipairs(vector.line(pos, dir, 50)) do
			if not table_contains(minetest.get_node(i).name, {"air", "ignore"}) then
				if light >= 1 then
					set_shadow(pos, 0)
				end
				return
			end
		end
		if light < 1 then
			calc_light(pos)
		end
	end,
})]]
