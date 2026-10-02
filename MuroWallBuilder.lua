local MWBLib = require('MWBLib')

local DEFAULT_WALL_TYPE = 'stone-wall'

local MuroWallBuilder = {
    NAME                = "muro-wall-builder", -- module name, see data.lua
    debug               = false,
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

    -- destruction (right-drag): trees/rocks always, player-built stuff
    -- only when the destroy-buildings setting is on.
    DECON_TYPES_ALL     = {'tree', 'simple-entity'},
    DECON_TYPES_MACHINES= {'cliffs',
                           'corpse',
                           'fish',
                           'electric-pole',
                           'inserter',
                           'transport-belt',
                           'loader',
                           'underground-belt',
                           'splitter',
                           'wall',
                           'gate',
                           'lamp',
                           'pipe',
                           'storage-tank',
                           'radar',
                           'rocket-silo',
                           'container',
                           'logistic-container',
                           'assembling-machine',
                           'furnace',
                           'lab',
                           'mining-drill',
                           'pump',
                           'offshore-pump',
                           'boiler',
                           'generator',
                           'solar-panel',
                           'accumulator',
                           'reactor',
                           'heat-pipe',
                           'electric-turret',
                           'ammo-turret',
                           'fluid-turret',
                           'artillery-turret',
                           'artillery-wagon',
                           'car',
                           'spider-vehicle',
                           'locomotive',
                           'cargo-wagon',
                           'fluid-wagon',
                           'train-stop',
                           'beacon',
                           'roboport',
                           'curved-rail-a',
                           'curved-rail-b',
                           'straight-rail',
                           'rail-ramp',
                           'elevated-straight-rail',
                           'elevated-curved-rail-a',
                           'elevated-curved-rail-b',
                           'elevated-half-diagonal-rail',
                           'half-diagonal-rail',
                           'rail-support',
                           'land-mine',
                           'market',
                           'programmable-speaker',
                           'linked-container',
                           'infinity-container',
                           'infinity-pipe',
                           'heat-interface',
                           'player-port'},
    destroy_buildings   = false,
    -- entity types this drag may clear out of the way; see
    -- compute_clearable_types(). Empty means "nothing may be cleared".
    clearable           = {},
    -- every type this mod can clear; anything outside it is not an obstacle
    blocking_types      = {},
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

function MuroWallBuilder:find_deconstructable_entities(position)
  local area              = MWBLib.prototype_position_to_area(position, self.wall_prototype, 2)
  local entities          = MWBLib.find_entities_by_types(self.player, area, {'tree', 'simple-entity'})
  local filtered_entities = {}

  for _,e in ipairs(entities) do
    local hash = MWBLib.hash_entity(e)
    -- self:log('entity ' .. e.name ..' hashed as ' .. hash)

    if not self.marked_for_deconstruct[hash] then
      filtered_entities[#filtered_entities + 1] = e
      self.marked_for_deconstruct[hash]         = 1
      self:log("add to list for deconstruct at idx " .. (#filtered_entities) .. ' : hash=' .. hash)
    end
  end

  return filtered_entities
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

function MuroWallBuilder:deconstruct_entities(entities)
  -- player+undo_index make these marks Ctrl+Z-able (trees/rocks aren't
  -- restorable by the game itself, matching vanilla deconstruction)
  return MWBLib.deconstruct_entities(self.player, entities, self:next_undo_index())
end

-- Types this drag may clear out of the way, as a set keyed by entity type.
-- Left-drag only ever touches trees/rocks, and only when the deconstruct
-- setting is on; the destructive right-drag additionally clears
-- player-built entities when the destroy-buildings setting is on.
function MuroWallBuilder:compute_clearable_types()
  local set = {}

  if self.destroying then
    for _,t in ipairs(self.DECON_TYPES_ALL) do
      set[t] = true
    end
    if self.destroy_buildings then
      for _,t in ipairs(self.DECON_TYPES_MACHINES) do
        set[t] = true
      end
    end
  elseif self.mark_for_deconstruction then
    for _,t in ipairs(self.DECON_TYPES_ALL) do
      set[t] = true
    end
  end

  return set
end

-- Types that can actually be in the way of a wall: the kinds of entity this
-- mod clears (trees, rocks, machines). Everything else has to be ignored,
-- because a logistic robot flying over the line, the character standing on
-- it, or an item on the ground are not obstacles - treating them as such
-- punched holes in the wall wherever one happened to be.
function MuroWallBuilder:compute_blocking_types()
  local set = {}

  for _,t in ipairs(self.DECON_TYPES_ALL) do
    set[t] = true
  end
  for _,t in ipairs(self.DECON_TYPES_MACHINES) do
    set[t] = true
  end

  return set
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
  local deconstructable = {}
  if self.mark_for_deconstruction then
    deconstructable = self:find_deconstructable_entities(position)
    if #deconstructable > 0 then
      self:deconstruct_entities(deconstructable)
    end
  end

  -- Decide the spot from what actually overlaps THIS tile, never from
  -- can_place_entity: with a ghost check type that call does not reliably
  -- report entities, which is how a left-drag ended up ghosting a building.
  -- The rule is per tile: every obstacle on the wall tile must be something
  -- this drag clears. Anything else skips the spot, which keeps left-drag
  -- off player-built entities while still letting the destructive right-drag
  -- ghost a tile whose buildings are on their way out. Only types that can
  -- really obstruct a wall count - see compute_blocking_types.
  local lt = {x = position.x - 0.5, y = position.y - 0.5}
  local rb = {x = position.x + 0.5, y = position.y + 0.5}
  local clearable_here = false

  for _,e in ipairs(self.player.surface.find_entities_filtered{area = {lt, rb}}) do
    -- Test the real overlap ourselves: an entity merely touching the tile
    -- edge must not count as being on it.
    if self.blocking_types[e.type] and not self:is_ignorable(e) and e.selection_box
        and MWBLib.boxes_overlap(lt, rb, e.selection_box) then
      if not self.clearable[e.type] then
        log('muro: skipping ' .. position.x .. ',' .. position.y ..
            ' - ' .. e.name .. ' (' .. e.type .. ') is not cleared by this drag')
        return
      end
      clearable_here = true
    end
  end

  -- Nothing real here, so the world itself has to allow a wall (not water,
  -- not a cliff, not off the map). build_check_type.ghost_place was removed
  -- in Factorio 1.1.6 (forum 70603), which is what left this check nil and
  -- silently refusing every occupied tile; `script` is what place_wall uses.
  if not clearable_here and not self.player.surface.can_place_entity({
    name=self.wall_name,
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.script }) then
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

-- All wall-spot positions (tile centers) the wall line/rectangle of the
-- given thickness occupies for a selection area: top line, sides, bottom
-- line. Single source of truth used by both building and destroying so the
-- destruction footprint always matches the wall footprint exactly.
function MuroWallBuilder:wall_spots(area, thickness)
  thickness = thickness or self.thickness
  local width  = math.floor(area.right_bottom.x - area.left_top.x + 0.5)
  local height = math.floor(area.right_bottom.y - area.left_top.y + 0.5)

  if width <= 0 and height <= 0 then
    return {}
  end
  if width <= 0 then
    width = thickness
  end
  if height <= 0 then
    height = thickness
  end

  local x1 = math.floor(area.left_top.x) + 0.5
  local y1 = math.floor(area.left_top.y) + 0.5
  local x2 = math.max(x1 + width, x1 + thickness - 1)

  local spots = {}
  local function line(ya, yb)
    for y = ya, yb do
      for x = x1, x2 do
        spots[#spots + 1] = {x = x, y = y}
      end
    end
  end

  -- top line (full)
  line(y1, y1 + thickness - 1)

  -- sides (middle only)
  for y = y1 + thickness, y1 + height - thickness do
    for i = 0, thickness - 1 do
      spots[#spots + 1] = {x = x1 + i, y = y}
      spots[#spots + 1] = {x = x2 - i, y = y}
    end
  end

  -- bottom line (full)
  local yb = math.max(y1, y1 + height - (thickness - 1))
  line(yb, yb + thickness - 1)

  return spots
end

function MuroWallBuilder:build(area, thickness)
  thickness = thickness or self.thickness

  self.marked_for_deconstruct = {}
  self.clearable = self:compute_clearable_types()

  for _,spot in ipairs(self:wall_spots(area, thickness)) do
    self:placer(spot)
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

function MuroWallBuilder:deconstruct_wall_footprint(event)
  local spots = self:wall_spots(event.area, self.thickness)
  if #spots == 0 then return end

  local types = {
    self.DECON_TYPES_ALL, -- trees, rocks: always
  }
  if self.destroy_buildings then
    types[#types + 1] = self.DECON_TYPES_MACHINES
  end

  local marked = 0

  for _,type_list in ipairs(types) do
    local entities = MWBLib.find_entities_by_types(self.player, event.area, type_list)
    for _,entity in ipairs(entities) do
      local box = entity.selection_box
      if box then
        for _,spot in ipairs(spots) do
          -- spot is a tile center; the wall's tile is the 1x1 square around it
          if MWBLib.boxes_overlap({x = spot.x - 0.5, y = spot.y - 0.5},
                                  {x = spot.x + 0.5, y = spot.y + 0.5}, box) then
            entity.order_deconstruction(self.player.force, self.player, self:next_undo_index())
            marked = marked + 1
            break
          end
        end
      end
    end
  end

  self:log('deconstruct_wall_footprint: marked ' .. marked .. ' entities')
end

-- Note: ghost mode only. cheat/instant-build mode bypasses
-- deconstruct-clearing entirely (documented behavior from 1.1).

function MuroWallBuilder:on_selected_area(event, thickness)
  self:log('on_selected_area ' .. event.name .. ', thickness = ' .. thickness)
  -- self.player.surface.deconstruct_area{
  --     area   = event.area,
  --     player = self.player,
  --     force  = self.player.force
    -- }
  local area = event.area

  if event.tiles and #event.tiles > 0 then
    local MAX_SIZE = 2000000 -- https://wiki.factorio.com/World_generator#Maximum_map_size_and_used_memory
    area = {left_top = {x = MAX_SIZE, y = MAX_SIZE}, right_bottom = {x = -MAX_SIZE, y = -MAX_SIZE}}
    local whichTiles = {left_top = {x = 0, y = 0}, right_bottom = {x=0, y=0}}
    -- find tile boundaries
    -- it appears tiles are in order from top left to bottom right,
    -- in columns, so we could be cleverer and shortcut this loop
    -- as long as we know the stride
    for i,tile in ipairs(event.tiles) do
      if tile.position.x < area.left_top.x then
        area.left_top.x = tile.position.x
        whichTiles.left_top.x = i
      end
      if tile.position.x > area.right_bottom.x then
        area.right_bottom.x = tile.position.x
        whichTiles.right_bottom.x = i
      end
      if tile.position.y < area.left_top.y then
        area.left_top.y = tile.position.y
        whichTiles.left_top.y = i
      end
      if tile.position.y > area.right_bottom.y then
        area.right_bottom.y = tile.position.y
        whichTiles.right_bottom.y = i
      end
    end
    -- self.player.print(MWBLib.dumps(whichTiles))
  end

  self:build(area, thickness)
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
      this:deconstruct_wall_footprint(event)
      -- after clearing, also lay the wall line over the dragged area
      this:on_selected_area(event, this.thickness)
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

  self.instant_build = self:get_setting('cheat')
  if self.instant_build then
    self.placer = self.place_wall
  else
    self.placer = self.place_wall_ghost
  end

  self.thickness               = self:get_setting('thickness') or self.thickness
  self.mark_for_deconstruction = self:get_setting('deconstruct') or self.mark_for_deconstruction
  self.alt_thickness           = self:get_setting('alt-thickness') or self.thickness
  self.destroy_buildings       = self:get_setting('destroy-buildings') or false
  self.clearable               = {}
  self.blocking_types          = self:compute_blocking_types()
  self.ghosted_tiles           = {} -- tiles this drag has already ghosted
  self.destroying              = false -- set true by the right-drag handler
  self.undo_is_new             = true -- each drag starts a fresh undo item

  -- self:log('local init finished, self = ' .. serpent.block(self))
end

return MuroWallBuilder