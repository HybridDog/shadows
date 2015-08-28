if true then
	return
end
-- ↑ remove these lines to enable the mod

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

local invisible_nodes = {air = true, ignore = true, ["shadows:shadow"] = true}
local shadowstep = 1

local c_air, c_ignore, c_shadow

local light_nodes, ch_nodes, unwanted_nexts
local function load_nodes()
	light_nodes = {}
	for n,i in pairs(minetest.registered_nodes) do
		local amount = i.light_source
		if amount then
			local light = amount-5
			if light > 0 then
				light_nodes[minetest.get_content_id(n)] = light
			end
		end
	end
	c_air = minetest.get_content_id("air")
	c_ignore = minetest.get_content_id("ignore")
	c_shadow = minetest.get_content_id("shadows:shadow")

	ch_nodes = {[c_air] = true, [c_shadow] = true}
	unwanted_nexts = {[c_air] = true, [c_ignore] = true, [c_shadow] = true}
end

local function seeable(x, y, z, data, area)
	for j = -1,1,2 do
		for _,i in pairs({
			{x+j, y, z},
			{x, y+j, z},
			{x, y, z+j},
		}) do
			if not unwanted_nexts[data[area:index(i[1], i[2], i[3])]] then
				return true
			end
		end
	end
	return false
end


-- store known visible node positions in a table
local hard_cache = {}
local function get_hard(pos)
	local hard = hard_cache[pos.z]
	if hard then
		hard = hard[pos.y]
		if hard then
			return hard[pos.x]
		end
	end
end

local function is_hard(pos)
	local hard = get_hard(pos)
	if hard ~= nil then
		return hard
	end
	hard = not invisible_nodes[minetest.get_node(pos).name]
	if hard_cache[pos.z] then
		if hard_cache[pos.z][pos.y] then
			hard_cache[pos.z][pos.y][pos.x] = hard
			return
		end
		hard_cache[pos.z][pos.y] = {[pos.x] = hard}
		return
	end
	hard_cache[pos.z] = {[pos.y] = {[pos.x] = hard}}
	return hard
end

local function remove_hard(pos)
	local hard = get_hard(pos)
	if hard == nil then
		return
	end
	hard_cache[pos.z][pos.y][pos.x] = nil
	if not next(hard_cache[pos.z][pos.y]) then
		hard_cache[pos.z][pos.y] = nil
	end
	if not next(hard_cache[pos.z]) then
		hard_cache[pos.z] = nil
	end
end


local cur_tab -- <— this must be defined here or earlier
local function shadow_here(pos)
	for _,i in ipairs(cur_tab) do
		if is_hard(vector.add(pos, i)) then
			return true
		end
	end
	return false
end

local function update_chunk(p, remove_shadows)
	if not light_nodes then
		-- load nodes into cache
		load_nodes()
	end

	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(p, vector.add(p, mmrange))
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	--
	local light_sources,n = {},1
	for k =p.z,p.z+mmrange do
		for j = p.y,p.y+mmrange do
			for i = p.x,p.x+mmrange do
				local p_pc = area:index(i, j, k)
				local d_p_pc = nodes[p_pc]
				if remove_shadows then
					if d_p_pc == c_shadow then
						nodes[p_pc] = c_air
					end
				else
					local light = light_nodes[d_p_pc]
					if light then
						light_sources[n] = {i,j,k, light}
						n = n+1
					elseif d_p_pc == c_shadow then
						if not seeable(i, j, k, nodes, area)
						or not shadow_here({x=i, y=j, z=k}) then
							nodes[p_pc] = c_air
						end
					elseif d_p_pc == c_air then
						if seeable(i, j, k, nodes, area)
						and shadow_here({x=i, y=j, z=k}) then
							nodes[p_pc] = c_shadow
						end
					end
				end
			end
		end
	end

	if n ~= 1 then
		-- remove shadows near light
		for _,t in pairs(light_sources) do
			for _,n in pairs(vector.explosion_table(t[4])) do
				local p = area:index(n[1].x+t[1], n[1].y+t[2], n[1].z+t[3])
				if nodes[p] == c_shadow then
					nodes[p] = c_air
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
