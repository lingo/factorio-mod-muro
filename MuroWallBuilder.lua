local MWBLib = require('MWBLib')

local DEFAULT_WALL_TYPE = 'stone-wall'

local MuroWallBuilder = {
    NAME                = "muro-wall-builder", -- module name, see data.lua
    debug               = false,
    debug               = true,
    player              = nil,
    instant_build       = false, -- build walls (if true) or ghosts?
    wall_prototype      = nil,
    wall_name           = DEFAULT_WALL_TYPE,
    thickness           = 1,
    alt_thickness       = 2,
    placer              = nil,
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
    -- self:log("muro: Skipping position where place is not allowed"..serpent.block(position))
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

function MuroWallBuilder:deconstruct_entities(entities)
  return MWBLib.deconstruct_entities(self.player, entities)
end

function MuroWallBuilder:place_wall_ghost(position)
  if self.mark_for_deconstruction then
    deconstructable = self:find_deconstructable_entities(position)
    if #deconstructable > 0 then
      self:deconstruct_entities(deconstructable)
    end
  end

  if not self.player.surface.can_place_entity({
    name=self.wall_name,
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.ghost_place }) then
      -- self:log("muro: Skipping position where place ghost is not allowed"..serpent.line(position))
      return
  end

  local entity = self.player.surface.create_entity{name="entity-ghost",
    inner_name=self.wall_name,
    expires=false,
    position=position,
    force=self.player.force,
    type='wall',
    raise_built=true
  }

  if #deconstructable > 0 then
    -- self:log('marked ' .. MWBLib.dumps(deconstructable) .. ' entities for destruction around ' .. serpent.line(position))
    -- self:log('place ghost at ' .. serpent.line(position) .. ' -> ' .. MWBLib.dumps(entity))
  end
end

-- place a line horizontally of wall ghosts
function MuroWallBuilder:place_wall_line(area, thickness)
  thickness = thickness or self.thickness
  local x2  = math.max(area.right_bottom.x, area.left_top.x + thickness -1)

  for i = 0, thickness-1 do
    for x = area.left_top.x, x2 do
      self:placer({x=x, y=area.left_top.y + i})
    end
  end
end

function MuroWallBuilder:place_wall_sides(area, thickness)
  thickness = thickness or self.thickness
  local x1  = area.left_top.x
  local x2  = math.max(area.right_bottom.x, x1 + thickness - 1)

  -- handle middle (only sides)
  for y = area.left_top.y+thickness, area.right_bottom.y-thickness do
    for i = 0, thickness-1 do
      self:placer({x = x1+i, y=y })
      self:placer({x = x2-i, y=y })
    end
  end

end

function MuroWallBuilder:build(area, thickness)
  thickness = thickness or self.thickness
  -- self:log('build ' .. serpent.line(area) .. ', ' .. thickness)
  -- player.print('wall area' .. serpent.block(area))
  -- self:log( "selcted_area, floored"..serpent.block(area) );

  -- Ensure rectangle is integral number of tiles wide/high
  width               = math.floor(area.right_bottom.x - area.left_top.x + 0.5)
  height              = math.floor(area.right_bottom.y - area.left_top.y + 0.5)
  area.left_top.x     = math.floor(area.left_top.x) + 0.5
  area.left_top.y     = math.floor(area.left_top.y) + 0.5
  area.right_bottom.x = area.left_top.x + width
  area.right_bottom.y = area.left_top.y + height

  self.marked_for_deconstruct = {}

  if width <= 0 and height <= 0 then
    return
  end
  if width <= 0 then
    width = thickness
  end
  if height <= 0 then
    height = thickness
  end

  -- player.print('muro WxH: ' .. width .. 'x' .. height)

  -- handle top line (full line)
  self:place_wall_line(area, thickness)

  -- handle sides
  self:place_wall_sides(area, thickness)

  -- handle bottom line (full line)
  area.left_top.y = math.max(area.left_top.y,  area.right_bottom.y - (thickness-1))
  self:place_wall_line(area, thickness)

  self:select_wallbuilder_tool()
end

function MuroWallBuilder:get_setting(args)
  is_global = args.is_global or false

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

function MuroWallBuilder:on_selected_area(event, thickness)
  self:log('on_selected_area ' .. event.name .. ', thickness = ' .. thickness)
  -- self.player.surface.deconstruct_area{
  --     area   = event.area,
  --     player = self.player,
  --     force  = self.player.force
    -- }
  area = event.area

  if #event.tiles then
    MAX_SIZE = 2000000 -- https://wiki.factorio.com/World_generator#Maximum_map_size_and_used_memory
    area = {left_top = {x = MAX_SIZE, y = MAX_SIZE}, right_bottom = {x = -MAX_SIZE, y = -MAX_SIZE}}
    whichTiles = {left_top = {x = 0, y = 0}, right_bottom = {x=0, y=0}}
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
  self.wall_prototype = game.entity_prototypes[self.wall_name]

  self.instant_build = self:get_setting('cheat')
  if self.instant_build then
    self.placer = self.place_wall
  else
    self.placer = self.place_wall_ghost
  end

  self.thickness               = self:get_setting('thickness') or self.thickness
  self.mark_for_deconstruction = self:get_setting('deconstruct') or self.mark_for_deconstruction
  self.alt_thickness           = self:get_setting('alt-thickness') or self.thickness

  -- self:log('local init finished, self = ' .. serpent.block(self))
end

return MuroWallBuilder