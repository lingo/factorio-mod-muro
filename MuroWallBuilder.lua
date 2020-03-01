local MWBLib = require('MWBLib')

local MuroWallBuilder = {
    NAME                = "muro-wall-builder", -- module name, see data.lua
    debug               = false,
    player              = nil,
    wall_prototype      = nil,
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
  local stack = MWBLib.find_entity_in_inventory(self.player, 'stone-wall')

  local can_place = self.player.surface.can_place_entity({
    name='stone-wall',
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.ghost_place
  })

  if not can_place then
    -- self:log("muro: Skipping position where place is not allowed"..serpent.block(position))
    return
  end

  local entity_name = 'stone-wall'

  if not self.player.cheat_mode and (stack == nil or stack.count < 1) then
    entity_name = 'entity-ghost'
  else
    if stack and stack.count > 0 then
      stack.count = stack.count - 1
    end
  end

  local entity = self.player.surface.create_entity{name=entity_name,
    inner_name='stone-wall',
    expires=false,
    position=position,
    raise_built=true,
    force=self.player.force,
    type='wall'
  }
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

function MuroWallBuilder:deconstruct_entites(entities)
  return MWBLib.deconstruct_entites(self.player, entities)
end

function MuroWallBuilder:place_wall_ghost(position)
  if self.mark_for_deconstruction then
    deconstructable = self:find_deconstructable_entities(position)
    if #deconstructable > 0 then
      self:deconstruct_entites(deconstructable)
    end
  end

  if not self.player.surface.can_place_entity({
    name='stone-wall',
    position=position,
    force=self.player.force,
    build_check_type=defines.build_check_type.ghost_place }) then
      -- self:log("muro: Skipping position where place ghost is not allowed"..serpent.line(position))
      return
  end

  local entity = self.player.surface.create_entity{name="entity-ghost",
    inner_name='stone-wall',
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
end

function MuroWallBuilder:get_settings()
  local setting = settings.get_player_settings(self.player)
  return setting
end

function MuroWallBuilder:get_setting(key)
  local settings = self:get_settings()

  if settings ~= nil then
    local setting = settings[self.NAME .. '-' .. key]

    if setting then
      return setting.value
    end
  end

  return nil
end

function MuroWallBuilder:on_setting_changed(event)
  if event.setting == self.NAME .. '-cheat' then
    if event.setting.value then
      self.placer = self.place_wall
    else
      self.placer = self.place_wall_ghost
    end
  elseif event.setting == self.NAME .. '-thickness' then
    self.thickness = event.value
  elseif event.setting == self.NAME .. '-alt-thickness' then
    self.alt_thickness = event.value
  elseif event.setting == self.NAME .. '-deconstruct' then
    self.mark_for_deconstruction = event.value
  end
end

function MuroWallBuilder:find_planner()
  return MWBLib.find_entity_in_inventory(self.player, self.NAME)
end

function MuroWallBuilder:select_wallbuilder_tool()
  local planner = self:find_planner(self.player)

  if planner == nil then
    self.player.begin_crafting{count=1, recipe=self.NAME}
  else
    self.player.cursor_stack.swap_stack(planner)
  end
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
  --   }
  self:build(event.area, thickness)
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
  self.wall_prototype = game.entity_prototypes['stone-wall']

  if self:get_setting('cheat') then
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