local MWBLib = {}

-- setmetatable(MWBLib, {__call = function(self,...) return self:init(...) end})
MWBLib.__index = MWBLib


function MWBLib.find_entity_in_inventory(player, entity_name)
  local inventories = {
    player.get_inventory(defines.inventory.character_main)
  }

  local entity = nil

  for _,inventory in ipairs(inventories) do
    entity = inventory.find_item_stack(entity_name)
    if entity then
      return entity
    end
  end
  return nil
end

function MWBLib.set_player_cursor_stack(player, entity_name)
  local stack = find_entity_in_inventory(player, entity_name)
  if stack ~= nil then
    player.cursor_stack.swap_stack(stack)
    return true
  end
  return false
end

function MWBLib.get_factorio_obj_data(obj)
    local keys = {
        'name', 'type', 'direction', 'count', 'position', 'bounding_box', 'selection_box'
    }
    local out = {}

    for _,key in ipairs(keys) do
        pcall(function()
            out[key] = obj[key]
        end)
    end
    if out.type and out.type:match('.*ghost') and obj.ghost_type then
        out.ghost_type = obj.ghost_type
        out.ghost_name = obj.ghost_name
    end

    -- out.help = obj.help()
    return out
end

function MWBLib.dumps(x, depth)
  depth = depth or 0

  if type(x) == 'table' then
    local out = {}
    for k,v in pairs(x) do
      if k == '__self' then
        out[#out+1] = MWBLib.dumps(MWBLib.get_factorio_obj_data(x), depth+1)
      else
        out[#out+1] = tostring(k) .. '=' .. MWBLib.dumps(v, depth+1)
      end
    end
    local spacer = ' '
    if depth > 0 then
        spacer = ''
    end
    return "{" ..spacer .. table.concat(out, ", ") .. spacer .."}"
  end

  return tostring(x)
end

function MWBLib.dump(x)
    print(MWBLib.dumps(x))
end

function MWBLib.tconcat(a,b)
  local c = {}
  for i,v in ipairs(a) do
    c[#c+1] = v
  end
  for i,v in ipairs(b) do
    c[#c+1] = v
  end
  return c
end


function MWBLib.prototype_position_to_area(position, prototype, multiplier)
  multiplier = multiplier or 1.0
  local box = prototype.selection_box
  local w2  = (box.right_bottom.x - box.left_top.x) / 2 * multiplier
  local h2  = (box.right_bottom.y - box.left_top.y) / 2 * multiplier

  local area = {
    {position.x - w2, position.y - h2},
    {position.x + w2, position.y + h2}
  }
  return area
end

function MWBLib.tappend(dest, append)
  for _,v in ipairs(append) do
    dest[#dest+1] = v
  end
end

function MWBLib.find_entities_by_types(player, area, types)
  local found = {}

  -- log('find_entities_by_types : found')
  -- for _,ent in ipairs(player.surface.find_entities(area)) do
  --   log(ent.name .. ' : type = ' .. ent.type .. ' : bounds = ' .. serpent.line(ent.bounding_box) .. ' : sel = ' .. serpent.line(ent.selection_box)
  --        .. ' : pos = ' .. serpent.line(ent.position))
  -- end

  for _,type in ipairs(types) do
    MWBLib.tappend(found, player.surface.find_entities_filtered{
        area=area,
        type=type
    })
  end
  return found
end

-- NtoZ and cantorPair come from
-- https://forums.factorio.com/viewtopic.php?f=34&t=41879
-- author: Betep3akata
-- https://forums.factorio.com/memberlist.php?mode=viewprofile&u=29421&sid=72481c6700ab33be88d6ed6e3b9ee9a7

-- Z -> N
local function NtoZ(x, y)
    return (x >= 0 and (x * 2) or (-x * 2 - 1)), (y >= 0 and (y * 2) or (-y * 2 - 1))
end

-- ZxZ -> N, i.e. (x, y) -> IDxy
local function cantorPair_v1(x, y)
    x,y = NtoZ(x, y)
    return (x + y +1)*(x + y)/2 + x
end
--
--

function MWBLib.hash_position(position)
    return cantorPair_v1(position.x or position[1], position.y or position[2])
end

function MWBLib.hash_bbox(box)
    return cantorPair_v1(MWBLib.hash_position(box.left_top), MWBLib.hash_position(box.right_bottom))
end

function MWBLib.deconstruct_entites(player, entities)
  if entities == nil or #entities == 0 then
    log("deconstruct_entites passed nil or empty list")
    return
  end

  for _,entity in ipairs(entities) do
    player.surface.deconstruct_area{
      area   = entity.bounding_box,
      player = player,
      force  = player.force
    }
  end
end

function MWBLib.hash_entity(entity)
    return MWBLib.hash_bbox(entity.bounding_box)
  -- return table.concat({
  --       entity.bounding_box.left_top.x,
  --       entity.bounding_box.left_top.y,
  --       entity.bounding_box.right_bottom.x,
  --       entity.bounding_box.right_bottom.y
  --   }, ':'
  --   )
  -- -- {
  --   entity.name,
  --   entity.bounding_box,
  --   (entity.position.x or entity.position[1]),
  --   (entity.position.y or entity.position[2])
  --   }, ':')
end


return MWBLib