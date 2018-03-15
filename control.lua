
local function is_empty_position(player, position)
  local entities = player.surface.find_entities({position,{position.x+1, position.y+1}})
  if #entities ~= 0 then
    log('muro ' .. 'found at position '..serpent.block(position) .. ' ' .. serpent.block(entities))
  end
  return #entities == 0
end

local function place_wall_ghost(player, position)
  if not player.surface.can_place_entity({
    name='stone-wall',
    position=position,
    force=player.force,
    build_check_type=defines.build_check_type.ghost_place
  }) then
    log("muro: Skipping position where place is not allowed"..serpent.block(position))
    return
  end
  player.surface.create_entity{name="entity-ghost",
    inner_name='stone-wall',
    expires=false,
    position=position,
    force=player.force,
    type='wall'
  }
end

-- place a line horizontally of wall ghosts
local function place_wall_line(player, area, thickness=1)
  for x = area.left_top.x, area.right_bottom.x do
    place_wall_ghost(player, {x=x, y=area.left_top.y})
  end
end

local function place_wall_sides(player, area, thickness=1)
end

local function build_walls(player, area, thickness=1)
  -- player.print('wall area' .. serpent.block(area))
  -- area.left_top.x     = math.floor(area.left_top.x + 0.5)
  -- area.left_top.y     = math.floor(area.left_top.y + 0.5)
  -- area.right_bottom.x = math.ceil(area.right_bottom.x)
  -- area.right_bottom.y = math.ceil(area.right_bottom.y)
  -- log( "selcted_area, floored"..serpent.block(area) );
  -- Ensure rectangle is integral number of tiles wide/high
  width               = math.floor(area.right_bottom.x - area.left_top.x + 0.5)
  height              = math.floor(area.right_bottom.y - area.left_top.y + 0.5)
  area.right_bottom.x = area.left_top.x + width
  area.right_bottom.y = area.left_top.y + height


  if width <= 0 and height <= 0 then
    return
  end
  if width <= 0 then
    width = 1
  end
  if height <= 0 then
    height = 1
  end


  -- player.print('muro WxH: ' .. width .. 'x' .. height)

  -- handle top line (full line)
  place_wall_line(player, area)

  if height > 1 then
    -- handle middle (only sides)
    for y = area.left_top.y+1, area.right_bottom.y-1 do
      place_wall_ghost(player, {x=area.left_top.x, y=y})
      place_wall_ghost(player, {x=area.right_bottom.x, y=y})
    end

    -- handle bottom line (full line)
    area.left_top.y = area.right_bottom.y;
    place_wall_line(player, area)
  end
end

local function find_entity_in_inventory(player, name)
  local main_inventory = player.get_inventory(defines.inventory.player_main)
  local quickbar       = player.get_inventory(defines.inventory.player_quickbar)
  local tools          = player.get_inventory(defines.inventory.player_tools)
  local entity         = main_inventory.find_item_stack(name)

  if entity == nil then
    entity = quickbar.find_item_stack(name)
  end
  if entity == nil then
    quickbar = player.get_quickbar()
    entity   = tools.find_item_stack(name)
  end
  if entity == nil then
    entity = quickbar.find_item_stack(name)
  end
  return entity
end

local function find_planner(player)
  return find_entity_in_inventory(player, 'muro-wall-builder')
end

local function on_selected_area(event)
  log( "selcted_area..."..serpent.block(event) );
  if event.item ~= "muro-wall-builder" then return end--If its not our wall builder, exit

  local player = game.players[event.player_index]
  -- local config = global["config"][player.name]

  -- log( "config?"..tostring(config))
  -- if config == nil then return end
                    -- global.temporary_ignore[entry.from] = true
                    -- surface.create_entity{name = "flying-text", position = {tile.position.x-1.3,tile.position.y-0.5}, text = {"insufficient-items"}, color = {r=1,g=0.6,b=0.6}}

  build_walls(player, event.area)
end

local function init_globals()
  if not global['muro-wall-builder'] then
    global['muro-wall-builder'] = {}
  end
end

script.on_event(defines.events.on_player_selected_area, function(event)
  init_globals()
  on_selected_area(event)
end)


script.on_event('muro-wall-builder', function(event)
  local player  = game.players[event.player_index]
  local planner = find_planner(player)

  if planner == nil then
    -- local muro_recipe = player.force.recipes['muro-wall-builder']
    player.begin_crafting{count=1, recipe='muro-wall-builder'}
  else
    player.cursor_stack.swap_stack(planner)
  end
end)

script.on_event(defines.events.on_player_crafted_item, function(event)
  local player = game.players[event.player_index]

  local item   = event.item_stack
  if item.name then
    item = item.name
  end

  local entity = find_entity_in_inventory(player, item)

  if entity then
    player.print('found item ' .. item .. ' now selecting')
    player.cursor_stack.swap_stack(entity)
    -- set_crafting_item(nil)
  else
    -- player.print("setting global to " .. item)
    -- set_crafting_item(item)
  end
end)

-- local function get_crafting_item()
--   if not global['muro-wall-builder'] or global['muro-wall-builder'].craft == nil then
--       return nil
--   end
--   return global['muro-wall-builder'].craft
-- end

-- local function find_last_crafted_entity(player)
--     local item = get_crafting_item()
--     if not item then
--       player.print("No global found" .. serpent.block(global['muro-wall-builder']))
--       return
--     end

--     player.print('seeking last crafted' .. item)

--     local  entity = find_entity_in_inventory(player, item)
--     return entity
-- end

-- script.on_event(defines.events.on_player_main_inventory_changed, function(event)
--     local player = game.players[event.player_index]
--     local entity = find_last_crafted_entity(player)

--     if entity then
--       set_crafting_item(nil)
--       player.cursor_stack.swap_stack(entity)
--     end
-- end)

-- script.on_event(defines.events.on_player_quickbar_inventory_changed, function(event)
--     local player = game.players[event.player_index]
--     local entity = find_last_crafted_entity(player)

--     if entity then
--       set_crafting_item(nil)
--       player.cursor_stack.swap_stack(entity)
--     end
-- end)


-- script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
--     local player = game.players[event.player_index]
--     if player.cursor_stack.valid_for_read then
--       if player.cursor_stack.name == 'muro-wall-builder' then
--       else
--       end
--     end
-- end)