-- Auto-closing doors
-- forked from homedecor's door code

autoclose_doors = {}

-- Boilerplate to support localized strings if intllib mod is installed.
local S
if autoclose_doors.intllib_modpath then
    dofile(autoclose_doors.intllib_modpath.."/intllib.lua")
    S = intllib.Getter(minetest.get_current_modname())
else
    S = function ( s ) return s end
end
autoclose_doors.gettext = S

--

function autoclose_doors.get_nodedef_field(nodename, fieldname)
	if not minetest.registered_nodes[nodename] then
		return nil
	end
	return minetest.registered_nodes[nodename][fieldname]
end

-- the model file

local modpath = minetest.get_modpath("autoclose_doors")
dofile(modpath.."/door_models.lua")

-- the good stuff!

local function isSolid(pos,adj)
    local adj = {x=adj[1],y=adj[2],z=adj[3]}
    local node = minetest.get_node(vector.add(pos,adj))
    if node then
        local idef = minetest.registered_nodes[minetest.get_node(vector.add(pos,adj)).name]
        if idef then
            return idef.walkable
        end
    end
    return false
end

local function countSolids(pos,node,level)
    local solids = 0
    for x = -1, 1 do
        for z = -1, 1 do
            local y = 0
            if node.param2 == 5 then 
                y = -level 
            else
                y =  level
            end
            -- special cases when x == z == 0
            if x == 0 and z == 0 then
                if level == 1 then
                    -- when looking past the trap door, cannot be solid in center
                    if isSolid(pos,{x,y,z}) then
                        return false
                    end
                    -- no else. it doesn't matter if x == y == z is solid, that's us.
                end
            elseif isSolid(pos,{x,y,z}) then
                solids = solids + 1
            end
        end
    end
    return solids
end

local function calculateClosed(pos)
    local node = minetest.get_node(pos)
    -- the door is considered closed if it is closing off something.

    local solids = 0
    local direction = node.param2 % 6
    local isTrap = direction == 0 or direction == 5
    if isTrap then
        -- the trap door is considered closed when all nodes on its sides are solid
        -- or all nodes in the 3x3 above/below it are solid except the center
        for level = 0, 1 do
            local fail = false
            local solids = countSolids(pos,node,level)
            if solids == 8 then
                return true
            end
        end
        return false
    else
        -- the door is considered closed when the nodes on its sides are solid
        -- or the 3 nodes in its facing direction are solid nonsolid solid

        -- sorry I dunno the math to figure whether to x or z
        if direction == 1 or direction == 2 then
            if isSolid(pos,{0,0,-1}) and isSolid(pos,{0,0,1}) then
                if string.find(node.name,'_bottom_') then
                    return calculateClosed({x=pos.x,y=pos.y+1,z=pos.z})
                else
                    return true
                end
            end
            local x
            if direction == 1 then
                x = 1
            else
                x = -1
            end
            if isSolid(pos,{x,0,-1}) and not isSolid(pos,{x,0,0}) and isSolid(pos,{x,0,1}) then
                if string.find(node.name,'_bottom_') then
                    return calculateClosed({x=pos.x,y=pos.y+1,z=pos.z})
                else
                    return true
                end
            end
            return false            
        else
            -- direction == 3 or 4                
            if isSolid(pos,{-1,0,0}) and isSolid(pos,{1,0,0}) then
                if string.find(node.name,'_bottom_') then
                    return calculateClosed({x=pos.x,y=pos.y+1,z=pos.z})
                else
                    return true
                end
            end
            local z
            if direction == 3 then
                z = 1
            else
                z = -1
            end
            if isSolid(pos,{-1,0,z}) and not isSolid(pos,{0,0,z}) and isSolid(pos,{1,0,z}) then
                if string.find(node.name,'_bottom_') then
                    return calculateClosed({x=pos.x,y=pos.y+1,z=pos.z})
                else
                    return true
                end
            end
            return false
        end
        error("What direction is this???",direction)
    end
end

-- isClosed flag, is 0 or 1 0 = open, 1 = closed
local function getClosed(pos)
    local isClosed = minetest.get_meta(pos):get_string('closed')
    if isClosed=='' then
        if calculateClosed(pos) then
            return true
        else
            return false
        end
    else
        isClosed = tonumber(isClosed)
        -- may be closed or open (1 or 0)
        return isClosed == 1
    end
end

local function addDoorNode(pos,def,isClosed)
    if isClosed then
        isClosed = 1
    else
        isClosed = 0
    end
    minetest.add_node(pos, def)
    minetest.get_meta(pos):set_int('closed',isClosed)
end

local sides = {"left", "right"}
local rsides = {"right", "left"}

for i in ipairs(sides) do
	local side = sides[i]
	local rside = rsides[i]

	for j in ipairs(autoclose_doors.door_models) do
		local doorname =			autoclose_doors.door_models[j][1]
		local doordesc =			autoclose_doors.door_models[j][2]
		local nodeboxes_top =		autoclose_doors.door_models[j][5]
		local nodeboxes_bottom =	autoclose_doors.door_models[j][6]
		local texalpha = false

		if side == "left" then
			nodeboxes_top =			autoclose_doors.door_models[j][3]
			nodeboxes_bottom =		autoclose_doors.door_models[j][4]
		end

		local lower_top_side = "autoclose_doors_"..doorname.."_tb.png"
		local upper_bottom_side = "autoclose_doors_"..doorname.."_tb.png"

		local tiles_upper = {
				"autoclose_doors_"..doorname.."_tb.png",
				upper_bottom_side,
				"autoclose_doors_"..doorname.."_lrt.png",
				"autoclose_doors_"..doorname.."_lrt.png",
				"autoclose_doors_"..doorname.."_"..rside.."_top.png",
				"autoclose_doors_"..doorname.."_"..side.."_top.png",
				}

		local tiles_lower = {
				lower_top_side,
				"autoclose_doors_"..doorname.."_tb.png",
				"autoclose_doors_"..doorname.."_lrb.png",
				"autoclose_doors_"..doorname.."_lrb.png",
				"autoclose_doors_"..doorname.."_"..rside.."_bottom.png",
				"autoclose_doors_"..doorname.."_"..side.."_bottom.png",
				}

		local selectboxes_top = {
				type = "fixed",
				fixed = { -0.5, -1.5, 6/16, 0.5, 0.5, 8/16}
			}

		local selectboxes_bottom = {
				type = "fixed",
				fixed = { -0.5, -0.5, 6/16, 0.5, 1.5, 8/16}
			}

		minetest.register_node("autoclose_doors:"..doorname.."_top_"..side, {
			description = doordesc.." "..S("(Top Half, %s-opening)"):format(side),
			drawtype = "nodebox",
			tiles = tiles_upper,
			paramtype = "light",
			paramtype2 = "facedir",
			groups = {snappy=3, not_in_creative_inventory=1},
			sounds = default.node_sound_wood_defaults(),
			walkable = true,
			use_texture_alpha = texalpha,
			selection_box = selectboxes_top,
			node_box = {
				type = "fixed",
				fixed = nodeboxes_top
			},
			drop = "autoclose_doors:"..doorname.."_bottom_"..side,
			after_dig_node = function(pos, oldnode, oldmetadata, digger)
				if minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == "autoclose_doors:"..doorname.."_bottom_"..side then
					minetest.remove_node({x=pos.x, y=pos.y-1, z=pos.z})
				end
			end,
			on_rightclick = function(pos, node, clicker)
				autoclose_doors.flip_door({x=pos.x, y=pos.y-1, z=pos.z}, node, clicker, doorname, side)
			end
		})

		local dgroups = {snappy=3, not_in_creative_inventory=1}
		if side == "left" then 
			dgroups = {snappy=3}
		end

		minetest.register_node("autoclose_doors:"..doorname.."_bottom_"..side, {
			description = doordesc.." "..S("(%s-opening)"):format(side),
			drawtype = "nodebox",
			tiles = tiles_lower,
			inventory_image = "autoclose_doors_"..doorname.."_left_inv.png",
			wield_image = "autoclose_doors_"..doorname.."_left_inv.png",
			paramtype = "light",
			paramtype2 = "facedir",
			groups = dgroups,
			sounds = default.node_sound_wood_defaults(),
			walkable = true,
			use_texture_alpha = texalpha,
			selection_box = selectboxes_bottom,
			on_timer = function(pos, elapsed)
				if not getClosed(pos) then
					local node = minetest.get_node(pos)
					autoclose_doors.flip_door(pos, node, nil, doorname, side, false)
				end
			end,
			node_box = {
				type = "fixed",
				fixed = nodeboxes_bottom
			},
			after_dig_node = function(pos, oldnode, oldmetadata, digger)
				if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == "autoclose_doors:"..doorname.."_top_"..side then
					minetest.remove_node({x=pos.x, y=pos.y+1, z=pos.z})
				end
			end,
			on_place = function(itemstack, placer, pointed_thing)
				local keys=placer:get_player_control()
				autoclose_doors.place_door(itemstack, placer, pointed_thing, doorname, keys["sneak"])
				return itemstack
			end,
			on_rightclick = function(pos, node, clicker)
				autoclose_doors.flip_door(pos, node, clicker, doorname, side)
			end,
            -- both left and right doors may be used for open or closed doors
            -- so they have to have both action_on and action_off and just
            -- check when that action is invoked if to continue

            on_punch = function(pos, node, puncher)
                minetest.get_meta(pos):set_string('closed',nil)
            end,
			drop = "autoclose_doors:"..doorname.."_bottom_left",
            mesecons = {
                effector = {
                    action_on = function(pos,node)
                        local isClosed = getClosed(pos)
                        if isClosed then
                            autoclose_doors.flip_door(pos,node,nil,doorname,side,isClosed)
                        end
                    end,
                    action_off = function(pos,node)
                        local isClosed = getClosed(pos)
                        if not isClosed then
                            autoclose_doors.flip_door(pos,node,nil,doorname,side,isClosed)
                        end
                    end
                }
            }
		})
	end
end

----- helper functions

function autoclose_doors.place_door(itemstack, placer, pointed_thing, name, forceright)

	local pointed = pointed_thing.under
	local pnode = minetest.get_node(pointed)
	local pname = pnode.name
	local rnodedef = minetest.registered_nodes[pname]

	if rnodedef then

		if rnodedef.on_rightclick then
			rnodedef.on_rightclick(pointed_thing.under, pnode, placer, itemstack)
			return
		end

		local pos1 = nil
		local pos2 = nil

		if rnodedef["buildable_to"] then
			pos1 = pointed
			pos2 = {x=pointed.x, y=pointed.y+1, z=pointed.z}
		else
			pos1 = pointed_thing.above
			pos2 = {x=pointed_thing.above.x, y=pointed_thing.above.y+1, z=pointed_thing.above.z}
		end

		local node_bottom = minetest.get_node(pos1)
		local node_top = minetest.get_node(pos2)

		if minetest.is_protected(pos1, placer:get_player_name()) then
			minetest.record_protection_violation(pos1,
					placer:get_player_name())
			return
		end

		if minetest.is_protected(pos2, placer:get_player_name()) then
			minetest.record_protection_violation(pos2,
					placer:get_player_name())
			return
		end

		if not autoclose_doors.get_nodedef_field(node_bottom.name, "buildable_to") 
		    or not autoclose_doors.get_nodedef_field(node_top.name, "buildable_to") then
			minetest.chat_send_player( placer:get_player_name(), S('Not enough space above that spot to place a door!') )
		else
			local fdir = minetest.dir_to_facedir(placer:get_look_dir())
			local p_tests = {
				{x=pos1.x-1, y=pos1.y, z=pos1.z},
				{x=pos1.x, y=pos1.y, z=pos1.z+1},
				{x=pos1.x+1, y=pos1.y, z=pos1.z},
				{x=pos1.x, y=pos1.y, z=pos1.z-1},
			}
			print("fdir="..fdir)
			local testnode = minetest.get_node(p_tests[fdir+1])
			local side = "left"

			if string.find(testnode.name, "autoclose_doors:"..name.."_bottom_left") or forceright then
				side = "right"
			end

            local def = { name = "autoclose_doors:"..name.."_bottom_"..side, param2=fdir}
            addDoorNode(pos1, def, true)
			minetest.add_node(pos2, { name = "autoclose_doors:"..name.."_top_"..side, param2=fdir})
			if not autoclose_doors.expect_infinite_stacks then
				itemstack:take_item()
				return itemstack
			end
		end
	end
end

-- to open a door, you switch left for right and subtract from param2, or vice versa right for left
-- that is to say open "right" doors become left door nodes, and open left doors right door nodes.
-- also adjusting param2 so the node is at 90 degrees.

function autoclose_doors.flip_door(pos, node, player, name, side, isClosed)
    if isClosed == nil then
        isClosed = getClosed(pos)
    end
    -- this is where we swap the isClosed status!
    -- i.e. if isClosed, we're adding an open door
    -- and if not isClosed, a closed door
    isClosed = not isClosed

	local rside = nil
	local nfdir = nil
	local ofdir = node.param2 or 0
	if side == "left" then
		rside = "right"
		nfdir=ofdir - 1
		if nfdir < 0 then nfdir = 3 end
	else
		rside = "left"
		nfdir=ofdir + 1
		if nfdir > 3 then nfdir = 0 end
	end
    local sound;
    if isClosed then
        sound = 'close'
    else
        sound = 'open'
    end
	minetest.sound_play("autoclose_doors_"..sound, {
		pos=pos,
        max_hear_distance = 5,
		gain = 2,
	})
    -- XXX: does the top half have to remember open/closed too?
	minetest.add_node({x=pos.x, y=pos.y+1, z=pos.z}, { name =  "autoclose_doors:"..name.."_top_"..rside, param2=nfdir})

    addDoorNode(pos,{ name = "autoclose_doors:"..name.."_bottom_"..rside, param2=nfdir },isClosed)

	local timer = minetest.get_node_timer(pos)
	if not isClosed then
		timer:start(10)
	end
end

