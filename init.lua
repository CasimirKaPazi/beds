beds = {}
beds.player = {}
beds.pos = {}

local player_in_bed = 0

-- help functions

local function get_look_yaw(pos)
	local n = minetest.get_node(pos)
	if n.param2 == 1 then
		return 7.9, n.param2
	elseif n.param2 == 3 then
		return 4.75, n.param2
	elseif n.param2 == 0 then
		return 3.15, n.param2
	else
		return 6.28, n.param2
	end
end


local function check_in_beds(players)
	local in_bed = beds.player
	if not players then
		players = minetest.get_connected_players()
	end

	for n, player in ipairs(players) do
		local name = player:get_player_name()
		if not in_bed[name] then
			return false
		end
	end

	return true
end

local function lay_down(player, pos, bed_pos, state)
	local name = player:get_player_name()
	local hud_flags = player:hud_get_flags()

	if not player or not name then
		return
	end

	-- stand up
	if state ~= nil and not state then
		local p = beds.pos[name] or nil
		if beds.player[name] ~= nil then
			beds.player[name] = nil
			player_in_bed = player_in_bed - 1
		end
		if p then 
			player:setpos(p)
		end

		-- physics, eye_offset, etc
		player:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
		player:set_look_yaw(math.random(1, 180)/100)
		default.player_attached[name] = false
		player:set_physics_override(1, 1, 1)
		hud_flags.wielditem = true
		default.player_set_animation(player, "stand" , 30)

	-- lay down
	else
		beds.player[name] = 1
		beds.pos[name] = pos
		player_in_bed = player_in_bed + 1

		-- physics, eye_offset, etc
		player:set_eye_offset({x=0,y=-13,z=0}, {x=0,y=0,z=0})
		local yaw, param2 = get_look_yaw(bed_pos)
		player:set_look_yaw(yaw)
		local dir = minetest.facedir_to_dir(param2)
		local p = {x=bed_pos.x+dir.x/2,y=bed_pos.y,z=bed_pos.z+dir.z/2}
		player:set_physics_override(0, 0, 0)
		player:setpos(p)
		default.player_attached[name] = true
		hud_flags.wielditem = false
		default.player_set_animation(player, "lay" , 0)
	end

	player:hud_set_flags(hud_flags)
end

local function update_message(finished)
	if finished then return end
	local ges = #minetest.get_connected_players()
	if ges == 1 then return end
	for name,_ in pairs(beds.player) do
		minetest.chat_send_player(name, ""..player_in_bed.." of "..ges.." players are in bed.")
	end
end


-- public functions

function beds.kick_players()
	for name,_ in pairs(beds.player) do
		local player = minetest.get_player_by_name(name)
		lay_down(player, nil, nil, false)
	end
end

function beds.skip_night()
	local tod = minetest.get_timeofday()
	if tod < 0.2 or tod > 0.805 then
		minetest.set_timeofday(0.22)
		minetest.chat_send_all("Good morning.")
	end
end

function beds.on_rightclick(pos, player)
	local name = player:get_player_name()
	local ppos = player:getpos()
	local tod = minetest.get_timeofday()

	-- move to bed
	if not beds.player[name] then
		lay_down(player, ppos, pos)
	else
		lay_down(player, nil, nil, false)
	end
	update_message(false)

	-- skip the night and let all stand up
	if check_in_beds() then
		minetest.after(2, function()
			beds.skip_night()
			beds.kick_players()
		end)
	end
end


-- callbacks
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	lay_down(player, nil, nil, false)
	beds.player[name] = nil
	if check_in_beds() then
		minetest.after(2, function()
			beds.skip_night()
			beds.kick_players()
		end)
	end
end)

-- nodes
dofile(minetest.get_modpath("beds").."/nodes.lua")
