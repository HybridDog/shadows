local range = 30

local function get_corner(pos)
	return {x=pos.x-pos.x%range, y=pos.y-pos.y%range, z=pos.z-pos.z%range}
end

local mmrange = range-1

local function table_contains(v, t)
	for _,i in ipairs(t) do
		if i==v then
			return true
		end
	end
	return false
end

local inv_nodes = {"air", "ignore", "shadows:shadow"}
local ch_nodes = {"air", "shadows:shadow"}
local shadowstep = 1

local function shadow_allowed(pos, nd)
	if not table_contains(nd, ch_nodes) then
		return false
	end
	for j = -1,1,2 do
		for _,i in ipairs({
			{x=pos.x+j, y=pos.y, z=pos.z},
			{x=pos.x, y=pos.y+j, z=pos.z},
			{x=pos.x, y=pos.y, z=pos.z+j},
		}) do
			if not table_contains(minetest.get_node(i).name, inv_nodes) then
				return true
			end
		end
	end
	return false
end

local cur_tab -- <— this must be defined here or earlier
local function shadow_here(pos)
	for _,i in ipairs(cur_tab) do
		if not table_contains(minetest.get_node(vector.add(pos, i)).name, inv_nodes) then
			return true
		end
	end
	return false
end


local c_air = minetest.get_content_id("air")
local c_ignore = minetest.get_content_id("ignore")
local c_shadow

local function update_chunk(p, remove_shadows)
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(p, vector.add(p, mmrange))
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	for k =p.z,p.z+mmrange do
		for j = p.y,p.y+mmrange do
			for i = p.x,p.x+mmrange do
				local pc = {x=i, y=j, z=k}
				local nd = minetest.get_node(pc).name
				if shadow_allowed(pc, nd)
				or remove_shadows then
					local shh
					if not remove_shadows then
						shh = shadow_here(pc)
					end
					local p_pc = area:indexp(pc)
					local d_p_pc = nodes[p_pc]
					if shh then
						if d_p_pc == c_air then
							nodes[p_pc] = c_shadow
						end
					elseif d_p_pc == c_shadow then
						nodes[p_pc] = c_air
					end
				end
			end
		end
	end

	manip:set_data(nodes)
	manip:write_to_map()
	manip:update_map()
end

minetest.register_node("shadows:shadow", {
	drawtype = "airlike",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	buildable_to = true,
	drop = ""
})

c_shadow = minetest.get_content_id("shadows:shadow")


local chunk_times = {}

local function update_chunks(clock, remove_shadows)
	for _,player in ipairs(minetest.get_connected_players()) do
		local pos = vector.round(player:getpos())
		if not pos then
			return
		end
		for a = -10,10,20 do
			for _,p in ipairs({
				{x=pos.x, y=pos.y, z=pos.z+a},
				{x=pos.x, y=pos.y+a, z=pos.z},
				{x=pos.x+a, y=pos.y, z=pos.z},
			}) do
				p = get_corner(p)
				local pstring = p.z.." "..p.y.." "..p.x
				local last_time = chunk_times[pstring]
				if not last_time
				or clock >= last_time+30 then
					update_chunk(p, remove_shadows)
					chunk_times[pstring] = clock
					minetest.chat_send_all(pstring)
				end
			end
		end
	end
end

local shtime = tonumber(os.clock())+5
minetest.register_globalstep(function()
	local clock = tonumber(os.clock())
	local delay = clock-shtime
	if delay < shadowstep then
		return
	end
	shtime = clock
	local dir = vector.sun_dir(minetest.get_timeofday())
	local remove_shadows
	if not dir then
		remove_shadows = true
	else
		cur_tab = vector.line(vector.zero, dir, 50)
	end
	update_chunks(clock, remove_shadows)
	print(string.format("[shadows] calculated after ca. %.2fs", os.clock() - clock))
end)

--[[
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
			if not table_contains(minetest.get_node(i).name, inv_nodes) then
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
			if not table_contains(minetest.get_node(i).name, inv_nodes) then
				return
			end
		end
		minetest.remove_node(pos)
	end,
})]]
