local MWBLib = require('MWBLib')
local MWB    = require('MuroWallBuilder')

script.on_init(function()
  MWB:init()
end)

script.on_load(function()
  MWB:init()
end)

-- local function find_entity_in_inventory(player, name)
--   local inventories = {
--     player.get_inventory(defines.inventory.player_main),
--     player.get_inventory(defines.inventory.player_quickbar),
--     player.get_inventory(defines.inventory.player_tools),
--     player.get_quickbar()
--   }

--   local entity = nil

--   for _,inventory in ipairs(inventories) do
--     entity = inventory.find_item_stack(name)
--     if entity then
--       return entity
--     end
--   end
--   return nil
-- end

-- local function set_player_cursor_stack(player, entity_name)
--   local stack = find_entity_in_inventory(player, entity_name)
--   if stack ~= nil then
--     -- log('found walls ' .. serpent.line(stack))
--     player.cursor_stack.swap_stack(stack)
--     return true
--   end
--   return false
-- end

-- local function place_wall(player, position)
--   local stack = find_entity_in_inventory(player, 'stone-wall')

--   -- if stack == nil then
--   --   log('Didnt find stone-wall in inventory')
--   -- end

--   -- log('stone-wall count is ' .. stack.count)

--   if not player.surface.can_place_entity({
--     name='stone-wall',
--     position=position,
--     force=player.force,
--     build_check_type=defines.build_check_type.ghost_place
--   }) then
--     -- log("muro: Skipping position where place is not allowed"..serpent.block(position))
--     return
--   end

--   local entity_name = 'stone-wall'
--   if not player.cheat_mode and (stack == nil or stack.count < 1) then
--     entity_name = 'entity-ghost'
--   else
--     if stack and stack.count > 0 then
--       stack.count = stack.count - 1
--     end
--   end

--   player.surface.create_entity{name=entity_name,
--     inner_name='stone-wall',
--     expires=false,
--     position=position,
--     force=player.force,
--     type='wall'
--   }
-- end

-- local function prototype_position_to_area(position, prototype)
--   local box  = prototype.selection_box
--   local w2    = (box.right_bottom.x - box.left_top.x) / 2
--   local h2    = (box.right_bottom.y - box.left_top.y) / 2

--   local area = {
--     {position.x - w2, position.y - h2},
--     {position.x + w2, position.y + h2}
--   }
--   return area
-- end

-- local function find_deconstructable_entities(player, position, prototype)
--   local area  = prototype_position_to_area(position, prototype)
--   local trees = player.surface.find_entities_filtered{
--     area=area,
--     type="tree"
--   }
--   local rocks = player.surface.find_entities_filtered{
--     area=area,
--     type="simple-entity"
--   }
--   return tconcat(trees, rocks)
-- end


-- local function deconstruct_entites(player, entities)
--   for _,entity in ipairs(entities) do
--     player.surface.deconstruct_area{
--       area   = entity.bounding_box,
--       player = player,
--       force  = player.force
--     }
--   end
-- end

-- local function place_wall_ghost(player, position)
--   local prototype = game.entity_prototypes['stone-wall']

--   deconstructable = find_deconstructable_entities(player, position, prototype)
--   if #deconstructable > 0 then
--     deconstruct_entites(player, deconstructable)
--   end

--   if not player.surface.can_place_entity({
--     name='stone-wall',
--     position=position,
--     force=player.force,
--     build_check_type=defines.build_check_type.ghost_place }) then
--       -- log("muro: Skipping position where place is not allowed"..serpent.block(position))
--       return
--   end

--   player.surface.create_entity{name="entity-ghost",
--     inner_name='stone-wall',
--     expires=false,
--     position=position,
--     force=player.force,
--     type='wall'
--   }
-- end

-- local placer = place_wall_ghost

-- local function init_cheat_mode(player)
--   local setting = settings.get_player_settings(player)["muro-wall-builder-cheat"]
--   -- log('init_cheat_mode, setting is ' .. serpent.line(setting))
--   if setting ~= nil and setting.value == true then
--     placer = place_wall
--   else
--     placer = place_wall_ghost
--   end
-- end

-- -- place a line horizontally of wall ghosts
-- local function place_wall_line(player, area, thickness)
--   if not thickness then thickness = 1; end
--   for i = 0, thickness-1 do
--     for x = area.left_top.x, area.right_bottom.x do
--       placer(player, {x=x, y=area.left_top.y + i})
--     end
--   end
-- end

-- local function place_wall_sides(player, area, thickness)
--   if not thickness then thickness = 1; end
--   -- handle middle (only sides)
--   for y = area.left_top.y+thickness, area.right_bottom.y-thickness do
--     for i = 0, thickness-1 do
--       placer(player, {x=area.left_top.x+i, y=y})
--       placer(player, {x=area.right_bottom.x-i, y=y})
--     end
--   end

-- end

-- local function build_walls(player, area, thickness)
--   if not thickness then thickness = 1; end
--   init_cheat_mode(player)
--   -- player.print('wall area' .. serpent.block(area))
--   -- log( "selcted_area, floored"..serpent.block(area) );

--   -- Ensure rectangle is integral number of tiles wide/high
--   width               = math.floor(area.right_bottom.x - area.left_top.x + 0.5)
--   height              = math.floor(area.right_bottom.y - area.left_top.y + 0.5)
--   area.right_bottom.x = area.left_top.x + width
--   area.right_bottom.y = area.left_top.y + height


--   if width <= 0 and height <= 0 then
--     return
--   end
--   if width <= 0 then
--     width = thickness
--   end
--   if height <= 0 then
--     height = thickness
--   end

--   -- player.print('muro WxH: ' .. width .. 'x' .. height)

--   -- handle top line (full line)
--   place_wall_line(player, area, thickness)

--   place_wall_sides(player, area, thickness)

--   -- handle bottom line (full line)
--   area.left_top.y = area.right_bottom.y - (thickness-1);
--   place_wall_line(player, area, thickness)
-- end

-- local function find_planner(player)
--   return find_entity_in_inventory(player, 'muro-wall-builder')
-- end

-- local function on_selected_area(event, thickness)
--   -- log( "selected_area..."..serpent.block(event) );
--   if event.item ~= "muro-wall-builder" then return end--If its not our wall builder, exit

--   local player = game.players[event.player_index]

--   build_walls(player, event.area, thickness)
-- end

-- script.on_event(defines.events.on_player_selected_area, function(event)
--   local thickness = 1
--   local player    = game.players[event.player_index]
--   local setting   = settings.get_player_settings(player)["muro-wall-builder-thickness"]
--   -- log('setting is '.. serpent.line(setting))
--   if setting and setting.value then
--     thickness = setting.value
--   end

--   on_selected_area(event, thickness)
-- end)

-- script.on_event(defines.events.on_player_alt_selected_area, function(event)
--   local thickness = 2
--   local player    = game.players[event.player_index]
--   local setting   = settings.get_player_settings(player)["muro-wall-builder-alt-thickness"]
--   -- log('setting is '.. serpent.line(setting))
--   if setting and setting.value then
--     thickness = setting.value
--   end

--   on_selected_area(event, thickness)
-- end)

-- script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
--   -- log('runtime setting changed ' .. serpent.line(event.setting))
--   if event.setting == 'muro-wall-builder-cheat' then
--     if event.setting.value then
--       placer = place_wall
--     else
--       placer = place_wall_ghost
--     end
--   end
--   return true
-- end)


-- script.on_event('muro-wall-builder', function(event)
--   local player  = game.players[event.player_index]
--   local planner = find_planner(player)

--   if planner == nil then
--     -- local muro_recipe = player.force.recipes['muro-wall-builder']
--     player.begin_crafting{count=1, recipe='muro-wall-builder'}
--   else
--     player.cursor_stack.swap_stack(planner)
--   end
-- end)

-- -- script.on_event(defines.events.on_player_crafted_item, function(event)
-- --   local player = game.players[event.player_index]

-- --   local item   = event.item_stack
-- --   if item.name then
-- --     item = item.name
-- --   end

-- --   local entity = find_entity_in_inventory(player, item)

-- --   if entity then
-- --     -- player.print('found item ' .. item .. ' now selecting')
-- --     player.cursor_stack.swap_stack(entity)
-- --   end
-- -- end)
