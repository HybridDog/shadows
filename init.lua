-- range of blocks updated next to the player's block (used for mapchunk size)
local block_range = 3

-- distance the nodes can cause shadows
local ray_length = 50

-- mapchunk update interval in gametime seconds
--~ local update_interval = 600
local update_interval = 1

-- shadow update test interval in seconds
local gstep_interval = 1

-- give brightness to shadows
local shadowlight = 6


-- returns the chunk position of the block containing pos
local chunkfactor = 1 / (block_range * 16)
local function get_chunkpos(pos)
	return {
		x = math.floor(pos.x * chunkfactor),
		y = math.floor(pos.y * chunkfactor),
		z = math.floor(pos.z * chunkfactor),
	}
end

-- a hash function for mapblock positions
local function mpos_shash(mpos)
	return mpos.z * 0x1000000
		+ mpos.y * 0x1000
		+ mpos.x
end

-- tells whether the node can carry light
local lightables = {}
local function is_lightable(id)
	if lightables[id] ~= nil then
		return lightables[id]
	end
	local def = minetest.registered_nodes[minetest.get_name_from_content_id(id)]
	lightables[id] = def and def.paramtype == "light"
	return lightables[id]
end

-- tells whether the node's param1 matters
local function seeable(vi, nodes, area)
	return is_lightable(nodes[vi])
		and not (
			is_lightable(nodes[vi + 1])
			and is_lightable(nodes[vi - 1])
			and is_lightable(nodes[vi + area.ystride])
			and is_lightable(nodes[vi - area.ystride])
			and is_lightable(nodes[vi + area.zstride])
			and is_lightable(nodes[vi - area.zstride])
		)
end

-- tells whether the node lets light pass
local light_propagaters = {[minetest.get_content_id"ignore"] = true}
local function propagates_light(id)
	if light_propagaters[id] ~= nil then
		return light_propagaters[id]
	end
	local def = minetest.registered_nodes[minetest.get_name_from_content_id(id)]
	light_propagaters[id] = def and def.sunlight_propagates
	return light_propagaters[id]
end

local cur_tab

-- searches for light blocking nodes in the path to sun
local function shadow_here(pos, nodes, area)
	for _,i in ipairs(cur_tab) do
		local p = vector.add(pos, i)
		if not area:containsp(p) then
			return false
		end
		if not propagates_light(nodes[area:indexp(p)]) then
			return true
		end
	end
	return false
end

local nodes = {}

-- updates shadows in the given mapchunks
local function update_chunk(mpos_min, mpos_max)
	local manip = minetest.get_voxel_manip()
	local minp = vector.multiply(mpos_min, 16)
	local maxp = vector.add(vector.multiply(mpos_max, 16), 15)
	local emin,emax = manip:read_from_map(
		vector.add(minp, -16),
		vector.add(maxp, 16)
	)
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local param1s = manip:get_light_data()
	manip:get_data(nodes)

	-- loop through the cube
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				-- test whether the node matters
				if seeable(vi, nodes, area) then
					-- remove current daylight
					param1s[vi] = param1s[vi] - (param1s[vi] % 16)
					if not shadow_here({x=x, y=y, z=z}, nodes, area) then
						-- set it to 15 if there's no shadow
						param1s[vi] = param1s[vi] + 15
					else
						param1s[vi] = param1s[vi] + shadowlight
					end
				end
				vi = vi+1
			end
		end
	end

	manip:set_light_data(param1s)
	manip:write_to_map(false)
end

-- updates the mapblocks around each player
local chunk_times = {}
local function update_chunks()
	local gametime = minetest.get_gametime()
	for _,player in ipairs(minetest.get_connected_players()) do
		local cpos_min = get_chunkpos(player:getpos())
		local chash = mpos_shash(cpos_min)
		if not chunk_times[chash]
		or gametime - chunk_times[chash] >= update_interval then
			chunk_times[chash] = gametime
			local mpos_min = vector.multiply(cpos_min, block_range)
			local mpos_max = vector.add(mpos_min, block_range-1)
			update_chunk(mpos_min, mpos_max)
			minetest.chat_send_all(minetest.pos_to_string(mpos_min))
		end
	end
end

local time = 0
minetest.register_globalstep(function(dtime)
	time = time + dtime
	if time < gstep_interval then
		return
	end
	time = 0

	local t0 = minetest.get_us_time()
	local dir = vector.sun_dir(minetest.get_timeofday())
	if not dir then
		-- TODO: moon shadows
		return
	end
	cur_tab = vector.line(vector.zero, dir, ray_length)
	update_chunks()
	minetest.chat_send_all("[shadows] calculated after ca. " ..
		math.floor((minetest.get_us_time() - t0) / 10000 + 0.5) / 100 .. " s")
end)
