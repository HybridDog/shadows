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

local function update_shadow(pos, nd)
	local shh = shadow_here(pos)
	if shh then
		if nd == "air" then
			minetest.set_node(pos, {name = "shadows:shadow"})
		end
	elseif nd == "shadows:shadow" then
		minetest.set_node(pos, {name = "air"})
	end
end

local function update_chunk(pos)
	local p = vector.chunkcorner(pos)
	for i = p.x,p.x+16 do
		for j = p.y,p.y+16 do
			for k =p.z,p.z+16 do
				local pc = {x=i, y=j, z=k}
				local nd = minetest.get_node(pc).name
				if shadow_allowed(pc, nd) then
					update_shadow(pc, nd)
				end
			end
		end
	end
end

minetest.register_node("shadows:shadow", {
	drawtype = "airlike",
	sunlight_propagates = false,
	walkable = false,
	pointable = false
})

local shtime = tonumber(os.clock())
minetest.register_globalstep(function()
	local delay = tonumber(os.clock())-shtime
	if delay < shadowstep then
		return
	end
	shtime = tonumber(os.clock())
	local dir = vector.sun_dir(minetest.get_timeofday())
	if not dir then
		return
	end
	local t1 = os.clock()
	cur_tab = vector.line(vector.zero, dir, 50)
	for _,player in ipairs(minetest.get_connected_players()) do
		local pos = player:getpos()
		if not pos then
			return
		end
		update_chunk(pos)
	end
	print(string.format("[shadows] calculated after ca. %.2fs", os.clock() - t1))
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
