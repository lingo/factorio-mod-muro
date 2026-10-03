local MWBLib = require('MWBLib')

local DEFAULT_WALL_TYPE = 'stone-wall'

local MuroWallBuilder = {
    NAME                = "muro-wall-builder", -- module name, see data.lua
    debug               = true,
    player              = nil,
    instant_build       = false, -- build walls (if true) or ghosts?
    wall_prototype      = nil,
    wall_name           = DEFAULT_WALL_TYPE,
    thickness           = 1,
    alt_thickness       = 2,
    placer              = nil,

    -- undo support (2.0 LuaUndoRedoStack): undo_index is the index of the
    -- undo item to add the action to; 0 creates a NEW item, and after that
    -- the new item is the most recent one, i.e. index 1.
    UNDO_NEW             = 0,
    UNDO_LAST            = 1,
    undo_is_new          = true,

    -- Prototype categories are discovered lazily from Factorio. Keeping the
    -- LuaCustomTables here (rather than in saved storage) means they are
    -- automatically rebuilt after every load and include prototypes from
    -- other mods.
    player_placeable_prototypes = nil,
    building_prototypes         = nil,
    destroy_buildings   = false,
    destroying          = false, -- true while handling a right-drag
    -- tiles this drag has already put a ghost on
    ghosted_tiles       = {},
}

-- setmetatable(MuroWallBuilder, {__call = function(self,...) return self:init(...) end})
MuroWallBuilder.__index = MuroWallBuilder

function MuroWallBuilder:log(message)
  if self.debug then
    log(message)
  end
end

function MuroWallBuilder:place_wall(position)
  local stack = MWBLib.find_entity_in_inventory(self.player, self.wall_name)
  local have_walls = stack ~= nil and stack.valid_for_read and stack.count >= 1

  local can_place = self.player.surface.can_place_entity({
    name=self.wall_name,
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.script
  })

  if not can_place then
    return
  end

  if self.instant_build and have_walls then
    MWBLib.clear_player_cursor_stack(self.player)
    self.player.cursor_stack.swap_stack(stack)
    self.player.build_from_cursor{
      position=position,
    }
  else
    self:place_wall_ghost(position)
  end
end

-- First call of a drag creates a fresh undo item (0); subsequent calls
-- merge into it (1 = most recent). local_init resets undo_is_new per drag.
function MuroWallBuilder:next_undo_index()
  if self.undo_is_new then
    self.undo_is_new = false
    return self.UNDO_NEW
  end
  return self.UNDO_LAST
end

-- These are semantic prototype filters, not entity-type allowlists. A new
-- Factorio or modded entity therefore participates automatically as soon as
-- it is a building or has an item that places it.
function MuroWallBuilder:ensure_prototype_categories()
  if self.player_placeable_prototypes and self.building_prototypes then
    return
  end

  self.player_placeable_prototypes = prototypes.get_entity_filtered{
    {filter = "item-to-place"}
  }
  self.building_prototypes = prototypes.get_entity_filtered{
    {filter = "building"}
  }
end

function MuroWallBuilder:is_natural_obstacle(entity)
  if entity.type == "tree" then
    return true
  end

  return entity.type == "simple-entity"
    and entity.prototype.count_as_rock_for_filtered_deconstruction == true
end

function MuroWallBuilder:is_player_placeable(entity)
  return self.player_placeable_prototypes[entity.name] ~= nil
end

function MuroWallBuilder:is_building_obstacle(entity)
  return self:is_player_placeable(entity)
    or self.building_prototypes[entity.name] ~= nil
end

-- Moving or temporary entities must not punch holes in the wall. Most have
-- no collision mask that intersects a wall and never reach this function;
-- these explicit exceptions cover the ones that can.
local NON_BLOCKING_TYPES = {
  ["character"] = true,
  ["combat-robot"] = true,
  ["construction-robot"] = true,
  ["corpse"] = true,
  ["fish"] = true,
  ["item-entity"] = true,
  ["logistic-robot"] = true,
  ["unit"] = true,
}

function MuroWallBuilder:is_non_blocking(entity)
  return NON_BLOCKING_TYPES[entity.type] == true
end

function MuroWallBuilder:may_clear(entity)
  if self:is_natural_obstacle(entity) then
    return self.destroying or self.mark_for_deconstruction
  end

  return self.destroying
    and self.destroy_buildings
    and self:is_player_placeable(entity)
end

function MuroWallBuilder:wall_collision_box(position)
  local box = self.wall_prototype.collision_box
  return {
    left_top = {
      x = position.x + box.left_top.x,
      y = position.y + box.left_top.y,
    },
    right_bottom = {
      x = position.x + box.right_bottom.x,
      y = position.y + box.right_bottom.y,
    },
  }
end

function MuroWallBuilder:entity_overlaps_box(entity, box)
  if MWBLib.boxes_overlap(box.left_top, box.right_bottom, entity.bounding_box) then
    return true
  end

  local secondary = entity.secondary_bounding_box
  return secondary ~= nil
    and MWBLib.boxes_overlap(box.left_top, box.right_bottom, secondary)
end

function MuroWallBuilder:entities_on_wall_spot(position)
  local box = self:wall_collision_box(position)
  local entities = self.player.surface.find_entities_filtered{
    area = box,
    -- EntitySearchFilters expects layer identifiers, not the complete
    -- CollisionMask structure returned by LuaEntityPrototype.
    collision_mask = self.wall_prototype.collision_mask.layers,
  }
  local overlapping = {}

  for _,entity in ipairs(entities) do
    if self:entity_overlaps_box(entity, box) then
      overlapping[#overlapping + 1] = entity
    end
  end

  return overlapping
end

function MuroWallBuilder:order_deconstruction_once(entity)
  local key
  if entity.unit_number then
    key = "unit:" .. entity.unit_number
  else
    key = entity.name .. ":" .. MWBLib.hash_entity(entity)
  end

  if self.marked_for_deconstruct[key] then
    return true
  end

  if entity.to_be_deconstructed() then
    self.marked_for_deconstruct[key] = true
    return true
  end

  local undo_was_new = self.undo_is_new
  local ordered = entity.order_deconstruction(
    self.player.force, self.player, self:next_undo_index())

  -- A rejected order must not consume this drag's fresh undo group.
  if not ordered and undo_was_new then
    self.undo_is_new = true
  end
  if ordered then
    self.marked_for_deconstruct[key] = true
  end

  return ordered
end

-- A ghost never blocks a build, and neither should anything sitting on a
-- tile this same drag has already ghosted: both must be ignored when
-- judging a tile, or a spot next to one of our own ghosts reads as
-- occupied and loses its wall.
function MuroWallBuilder:is_ignorable(entity)
  if entity.type == "entity-ghost" or entity.name == "entity-ghost" then
    return true
  end

  return self.ghosted_tiles[math.floor(entity.position.x) .. ',' ..
                             math.floor(entity.position.y)] == true
end

function MuroWallBuilder:place_wall_ghost(position)
  local clearable = {}

  -- Validate every colliding entity before marking any of them. That avoids
  -- partially deconstructing a tile whose remaining blocker prevents a wall.
  for _,entity in ipairs(self:entities_on_wall_spot(position)) do
    if not self:is_ignorable(entity) and not self:is_non_blocking(entity) then
      local is_obstacle = self:is_natural_obstacle(entity)
        or self:is_building_obstacle(entity)

      if not is_obstacle or not self:may_clear(entity) then
        log('muro: skipping ' .. position.x .. ',' .. position.y ..
            ' - ' .. entity.name .. ' (' .. entity.type .. ') is not cleared by this drag')
        return
      end

      clearable[#clearable + 1] = entity
    end
  end

  for _,entity in ipairs(clearable) do
    if not self:order_deconstruction_once(entity) then
      log('muro: skipping ' .. position.x .. ',' .. position.y ..
          ' - could not order deconstruction of ' .. entity.name)
      return
    end
  end

  -- script_ghost checks terrain and prototype-specific placement rules.
  -- forced is limited to spots whose blockers were validated and marked
  -- above, so normal drags can never ghost over an uncleared building.
  if not self.player.surface.can_place_entity({
    name=self.wall_name,
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.script_ghost,
    forced=#clearable > 0 }) then
    log('muro: skipping ' .. position.x .. ',' .. position.y ..
        ' - the world does not allow a wall here')
    return
  end

  local entity = self.player.surface.create_entity{name="entity-ghost",
    inner_name=self.wall_name,
    expires=false,
    position=position,
    force=self.player.force,
    player=self.player,
    undo_index=self:next_undo_index(),
    raise_built=true
  }

  if entity then
    -- so this drag's own ghosts are never mistaken for obstacles
    self.ghosted_tiles[math.floor(position.x) .. ',' ..
                       math.floor(position.y)] = true
  else
    log('muro: the game refused a wall ghost at ' .. position.x .. ',' .. position.y)
  end
end

-- All wall-spot positions (tile centers) occupied by the outline of the
-- selected rectangle. Generate each spot once so narrow selections and
-- overlapping thick edges cannot add an extra row/column or duplicates.
function MuroWallBuilder:wall_spots(area, thickness)
  thickness = thickness or self.thickness
  local width = math.max(thickness,
    math.floor(area.right_bottom.x - area.left_top.x + 0.5))
  local height = math.max(thickness,
    math.floor(area.right_bottom.y - area.left_top.y + 0.5))

  local x1 = math.floor(area.left_top.x) + 0.5
  local y1 = math.floor(area.left_top.y) + 0.5
  local spots = {}

  for y = 0, height - 1 do
    for x = 0, width - 1 do
      if y < thickness or y >= height - thickness
          or x < thickness or x >= width - thickness then
        spots[#spots + 1] = {x = x1 + x, y = y1 + y}
      end
    end
  end

  return spots
end

function MuroWallBuilder:build(area, thickness)
  thickness = thickness or self.thickness

  self.marked_for_deconstruct = {}

  for _,spot in ipairs(self:wall_spots(area, thickness)) do
    self:placer(spot)
  end

  self:select_wallbuilder_tool()
end

function MuroWallBuilder:deconstruct_wall_spot(position)
  for _,entity in ipairs(self:entities_on_wall_spot(position)) do
    if not self:is_ignorable(entity) and not self:is_non_blocking(entity)
        and self:may_clear(entity) then
      if not self:order_deconstruction_once(entity) then
        log('muro: could not order deconstruction of ' .. entity.name ..
            ' at ' .. position.x .. ',' .. position.y)
      end
    end
  end
end

function MuroWallBuilder:deconstruct(area, thickness)
  thickness = thickness or self.thickness
  self.marked_for_deconstruct = {}

  for _,spot in ipairs(self:wall_spots(area, thickness)) do
    self:deconstruct_wall_spot(spot)
  end

  self:select_wallbuilder_tool()
end

function MuroWallBuilder:get_setting(args)
  local is_global = args.is_global or false

  if not (args.full_key or args.key or args[1] or type(args) == 'string') then
    self:log('get_setting called without a key')
    return nil
  end

  local settings = is_global and settings.global or settings.get_player_settings(self.player)

  if settings ~= nil then
    local key = args.full_key
      or (self.NAME .. '-' .. (args.key or args[1] or args))
    local setting = settings[key]

    if setting then
      return setting.value
    end
  end

  return nil
end

function MuroWallBuilder:on_setting_changed(event)
  local value = self:get_setting{
    full_key = event.setting,
    is_global = event.setting_type == 'runtime-global'
  }

  if event.setting == self.NAME .. '-cheat' then
    self.instant_build = value

    if value then
      self.placer = self.place_wall
    else
      self.placer = self.place_wall_ghost
    end
  elseif event.setting == self.NAME .. '-thickness' then
    self.thickness = value
  elseif event.setting == self.NAME .. '-alt-thickness' then
    self.alt_thickness = value
  elseif event.setting == self.NAME .. '-deconstruct' then
    self.mark_for_deconstruction = value
  end
end

function MuroWallBuilder:find_planner()
  return MWBLib.find_entity_in_inventory(self.player, self.NAME)
end

function MuroWallBuilder:select_wallbuilder_tool()
  MWBLib.clear_player_cursor_stack(self.player)
  self.player.cursor_stack.set_stack({ name = self.NAME, count = 1 })
end

function MuroWallBuilder:set_player_from_event(event)
  if not event.player_index then
    -- self:log('no player in event : ' .. serpent.block(event))
    return
  end
  self.player = game.players[event.player_index]
  self:log('player set from event = ' .. self.player.name)
end

-- Normal selection clears natural obstacles only while building ghosts;
-- reverse selection remains a deconstruction-only operation in every mode.

function MuroWallBuilder:selection_area(event)
  local area = event.area

  if event.tiles and #event.tiles > 0 then
    local MAX_SIZE = 2000000 -- https://wiki.factorio.com/World_generator#Maximum_map_size_and_used_memory
    area = {left_top = {x = MAX_SIZE, y = MAX_SIZE}, right_bottom = {x = -MAX_SIZE, y = -MAX_SIZE}}
    for _,tile in ipairs(event.tiles) do
      if tile.position.x < area.left_top.x then
        area.left_top.x = tile.position.x
      end
      if tile.position.x > area.right_bottom.x then
        area.right_bottom.x = tile.position.x
      end
      if tile.position.y < area.left_top.y then
        area.left_top.y = tile.position.y
      end
      if tile.position.y > area.right_bottom.y then
        area.right_bottom.y = tile.position.y
      end
    end

    -- Tile positions name their top-left corners; wall_spots expects an area
    -- whose right/bottom edge is exclusive.
    area.right_bottom.x = area.right_bottom.x + 1
    area.right_bottom.y = area.right_bottom.y + 1
  end

  return area
end

function MuroWallBuilder:on_selected_area(event, thickness)
  self:log('on_selected_area ' .. event.name .. ', thickness = ' .. thickness)
  self:build(self:selection_area(event), thickness)
end



function MuroWallBuilder:bind_events()
  local this = self

  script.on_event(defines.events.on_player_selected_area, function(event)
    local success,returnValue = pcall(function()
      if event.item ~= this.NAME then return; end --If its not our wall builder, exit
      this:local_init(event)
      return this:on_selected_area(event, this.thickness)
    end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)

  script.on_event(defines.events.on_player_alt_selected_area, function(event)
    local success,returnValue = pcall(function()
      if event.item ~= this.NAME then return; end --If its not our wall builder, exit
      this:local_init(event)
      return this:on_selected_area(event, this.alt_thickness)
      end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)

  script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    local success,returnValue = pcall(function()
      this:local_init(event)
      this:on_setting_changed(event)
      end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)

  script.on_event(defines.events.on_player_reverse_selected_area, function(event)
    local success,returnValue = pcall(function()
      if event.item ~= this.NAME then return; end --If its not our wall builder, exit
      this:local_init(event)
      this.destroying = true -- right-drag is the destructive mode
      this:deconstruct(this:selection_area(event), this.thickness)
      end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)

  script.on_event(defines.events.on_lua_shortcut, function(event)
    local success,returnValue = pcall(function()
      if event.prototype_name ~= this.NAME then return; end --If its not our wall builder, exit
      this:local_init(event)
      this:select_wallbuilder_tool()
      end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)

  script.on_event(MuroWallBuilder.NAME, function(event)
    local success,returnValue = pcall(function()
      -- self:log('custom event' .. serpent.block(event))
      -- this:set_player_from_event(event)
      this:local_init(event)
      this:select_wallbuilder_tool()
      end)
    if success then
      return returnValue
    end
    log(returnValue)
    return false
  end)
end

function MuroWallBuilder:init()
  self:log('MuroWallBuilder::init')

  local this = self

  self:bind_events()
  -- self:log('init finished, self = ' .. serpent.block(self))
end


function MuroWallBuilder:local_init(event)
  self:set_player_from_event(event)

  self.wall_name = self:get_setting('wall-name') or DEFAULT_WALL_TYPE
  self.wall_prototype = prototypes.entity[self.wall_name]
  self:ensure_prototype_categories()

  self.instant_build = self:get_setting('cheat')
  if self.instant_build then
    self.placer = self.place_wall
  else
    self.placer = self.place_wall_ghost
  end

  self.thickness = self:get_setting('thickness') or self.thickness
  local mark_for_deconstruction = self:get_setting('deconstruct')
  if mark_for_deconstruction ~= nil then
    self.mark_for_deconstruction = mark_for_deconstruction
  end
  self.alt_thickness     = self:get_setting('alt-thickness') or self.thickness
  self.destroy_buildings = self:get_setting('destroy-buildings') or false
  self.ghosted_tiles           = {} -- tiles this drag has already ghosted
  self.destroying              = false -- set true by the right-drag handler
  self.undo_is_new             = true -- each drag starts a fresh undo item

  -- self:log('local init finished, self = ' .. serpent.block(self))
end

return MuroWallBuilder
