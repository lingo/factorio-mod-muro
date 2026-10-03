-- Run from the mod root with:
--   texlua tests/test_muro_wall_builder.lua
-- or:
--   lua tests/test_muro_wall_builder.lua

package.path = "./?.lua;" .. package.path

log = function(_message) end
defines = {build_check_type = {script_ghost = 4}}

local MuroWallBuilder = require("MuroWallBuilder")
local MWBLib = require("MWBLib")

local tests_run = 0

local function test(name, fn)
  local ok, message = pcall(fn)
  if not ok then
    io.stderr:write("FAIL: " .. name .. "\n" .. message .. "\n")
    os.exit(1)
  end
  tests_run = tests_run + 1
  print("PASS: " .. name)
end

local function box(x1, y1, x2, y2)
  return {
    left_top = {x = x1, y = y1},
    right_bottom = {x = x2, y = y2},
  }
end

local function fake_entity(spec)
  local ordered = 0
  local result = {
    name = spec.name,
    type = spec.type,
    prototype = spec.prototype or {},
    position = spec.position or {x = 0.5, y = 0.5},
    bounding_box = spec.bounding_box or box(0.1, 0.1, 0.9, 0.9),
    secondary_bounding_box = spec.secondary_bounding_box,
    unit_number = spec.unit_number,
    ghost_name = spec.ghost_name,
    ghost_type = spec.ghost_type,
    to_be_deconstructed = function() return spec.already_marked or false end,
    order_deconstruction = function()
      ordered = ordered + 1
      return spec.order_succeeds ~= false
    end,
  }
  result.order_count = function() return ordered end
  return result
end

local function fake_builder(entities, options)
  options = options or {}
  local created = 0
  local last_filter
  local last_build_check
  local collision_layers = {object = true, player = true}
  local surface = {
    find_entities_filtered = function(filter)
      last_filter = filter
      local filtered = {}
      for _,entity in ipairs(entities) do
        local type_matches = not filter.type or entity.type == filter.type
        local area_matches = not filter.area or MWBLib.boxes_overlap(
          filter.area.left_top, filter.area.right_bottom, entity.bounding_box)
        if type_matches and area_matches then
          filtered[#filtered + 1] = entity
        end
      end
      return filtered
    end,
    can_place_entity = function(args)
      last_build_check = args
      return options.can_place ~= false
    end,
    create_entity = function()
      created = created + 1
      return {valid = true}
    end,
  }
  local result = setmetatable({
    player = {surface = surface, force = "player"},
    wall_name = "stone-wall",
    wall_prototype = {
      collision_box = box(-0.5, -0.5, 0.5, 0.5),
      collision_mask = {
        layers = collision_layers,
        not_colliding_with_itself = false,
      },
    },
    player_placeable_prototypes = options.placeable or {},
    building_prototypes = options.buildings or {},
    destroying = options.destroying or false,
    destroy_buildings = options.destroy_buildings or false,
    mark_for_deconstruction = options.mark_natural or false,
    marked_for_deconstruct = {},
    ghosted_tiles = {},
    undo_is_new = true,
    thickness = options.thickness or 1,
    select_wallbuilder_tool = function() end,
  }, {__index = MuroWallBuilder})
  result.created_count = function() return created end
  result.last_filter = function() return last_filter end
  result.last_build_check = function() return last_build_check end
  result.collision_layers = collision_layers
  return result
end

test("bounding-box overlap is strict at shared edges", function()
  local target = box(0, 0, 1, 1)
  assert(MWBLib.boxes_overlap(
    target.left_top, target.right_bottom, box(0.5, 0.5, 1.5, 1.5)))
  assert(not MWBLib.boxes_overlap(
    target.left_top, target.right_bottom, box(1, 0, 2, 1)))
  assert(not MWBLib.boxes_overlap(
    target.left_top, target.right_bottom, box(-1, -1, 0, 0)))
end)

test("prototype positions expand to centered search areas", function()
  local prototype = {selection_box = box(-0.4, -0.6, 0.4, 0.6)}
  local result = MWBLib.prototype_position_to_area(
    {x = 10, y = -5}, prototype, 2)
  assert(result[1][1] == 9.2 and result[1][2] == -6.2)
  assert(result[2][1] == 10.8 and result[2][2] == -3.8)
end)

test("position and bounding-box hashes are stable and distinguish coordinates", function()
  local origin = MWBLib.hash_position{x = 0, y = 0}
  assert(origin == MWBLib.hash_position{0, 0})
  assert(origin ~= MWBLib.hash_position{x = 1, y = 0})
  assert(MWBLib.hash_position{x = -1, y = 2}
    == MWBLib.hash_position{x = -1, y = 2})
  assert(MWBLib.hash_bbox(box(-1, -2, 3, 4))
    ~= MWBLib.hash_bbox(box(-1, -2, 3, 5)))
end)

test("one-tile-wide selections create one column", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 1, 5), 1)
  assert(#spots == 5, "expected 5 spots, got " .. #spots)
  for _,spot in ipairs(spots) do
    assert(spot.x == 0.5, "unexpected second column at x=" .. spot.x)
  end
end)

test("rectangle outlines contain no duplicate corners", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 5, 5), 1)
  assert(#spots == 16, "5x5 perimeter should contain 16 spots")
end)

test("single-thickness perimeter excludes interior tiles", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 4, 3), 1)
  local occupied = {}
  for _,spot in ipairs(spots) do
    occupied[spot.x .. "," .. spot.y] = true
  end
  assert(#spots == 10, "4x3 perimeter should contain 10 spots")
  assert(not occupied["1.5,1.5"])
  assert(not occupied["2.5,1.5"])
  assert(occupied["0.5,0.5"] and occupied["3.5,2.5"])
end)

test("thick perimeter leaves only the expected center", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 5, 5), 2)
  local occupied = {}
  for _,spot in ipairs(spots) do
    occupied[spot.x .. "," .. spot.y] = true
  end
  assert(#spots == 24, "5x5 thickness-2 perimeter should contain 24 spots")
  assert(not occupied["2.5,2.5"])
end)

test("thickness larger than the selection produces a filled minimum square", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 1, 1), 3)
  assert(#spots == 9, "thickness 3 should produce a 3x3 minimum footprint")
end)

test("wall geometry is aligned correctly at negative coordinates", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(-3, -2, -1, 1), 1)
  local occupied = {}
  for _,spot in ipairs(spots) do
    occupied[spot.x .. "," .. spot.y] = true
  end
  assert(#spots == 6)
  assert(occupied["-2.5,-1.5"])
  assert(occupied["-1.5,0.5"])
end)

test("alternate thickness expands a narrow selection once", function()
  local builder = fake_builder({})
  local spots = builder:wall_spots(box(0, 0, 1, 5), 2)
  assert(#spots == 10, "expected a 2x5 filled outline")
end)

test("tile positions become exclusive selection bounds", function()
  local builder = fake_builder({})
  local selected = builder:selection_area{
    area = box(3, 2, 3, 4),
    tiles = {
      {position = {x = 3, y = 2}},
      {position = {x = 3, y = 3}},
      {position = {x = 3, y = 4}},
    },
  }
  assert(selected.left_top.x == 3 and selected.right_bottom.x == 4)
  assert(selected.left_top.y == 2 and selected.right_bottom.y == 5)
  local spots = builder:wall_spots(selected, 1)
  assert(#spots == 3)
  for _,spot in ipairs(spots) do assert(spot.x == 3.5) end
end)

test("cursor selection bounds snap outward to whole tiles", function()
  local builder = fake_builder({})
  local selected = builder:selection_area{
    area = box(-2.5, -1.5, 4.5, 7.5),
  }
  assert(selected.left_top.x == -3 and selected.right_bottom.x == 5)
  assert(selected.left_top.y == -2 and selected.right_bottom.y == 8)

  local aligned = builder:selection_area{
    area = box(-2, -1, 4, 7),
    tiles = {},
  }
  assert(aligned.left_top.x == -2 and aligned.right_bottom.x == 4)
  assert(aligned.left_top.y == -1 and aligned.right_bottom.y == 7)
end)

test("selection bounds handle negative tile coordinates", function()
  local builder = fake_builder({})
  local selected = builder:selection_area{
    area = box(0, 0, 0, 0),
    tiles = {
      {position = {x = -3, y = -2}},
      {position = {x = -1, y = 1}},
    },
  }
  assert(selected.left_top.x == -3 and selected.right_bottom.x == 0)
  assert(selected.left_top.y == -2 and selected.right_bottom.y == 2)
end)

test("wall collision boxes are translated from prototype coordinates", function()
  local builder = fake_builder({})
  builder.wall_prototype.collision_box = box(-0.3, -0.4, 0.3, 0.4)
  local translated = builder:wall_collision_box({x = -2.5, y = 7.5})
  assert(translated.left_top.x == -2.8)
  assert(translated.left_top.y == 7.1)
  assert(translated.right_bottom.x == -2.2)
  assert(translated.right_bottom.y == 7.9)
end)

test("entity overlap uses strict edges and secondary rail boxes", function()
  local builder = fake_builder({})
  local wall = box(0, 0, 1, 1)
  local touching = fake_entity{
    name = "touching", type = "simple-entity",
    bounding_box = box(1, 0, 2, 1),
  }
  assert(not builder:entity_overlaps_box(touching, wall))

  local rail = fake_entity{
    name = "curved-rail", type = "curved-rail-a",
    bounding_box = box(2, 2, 3, 3),
    secondary_bounding_box = box(0.25, 0.25, 0.75, 0.75),
  }
  assert(builder:entity_overlaps_box(rail, wall))
end)

test("entity searches receive collision layers, not a CollisionMask", function()
  local builder = fake_builder({})
  builder:entities_on_wall_spot({x = 0.5, y = 0.5})
  local received = builder.last_filter().collision_mask
  assert(received == builder.collision_layers)
  assert(received.layers == nil)
end)

test("ghost searches bypass collision-mask filtering", function()
  local builder = fake_builder({})
  builder:ghosts_on_wall_spot({x = 0.5, y = 0.5})
  local received = builder.last_filter()
  assert(received.type == "entity-ghost")
  assert(received.force == builder.player.force)
  assert(received.collision_mask == nil)
end)

test("prototype categories are calculated once and cached", function()
  local previous_prototypes = prototypes
  local calls = 0
  prototypes = {
    get_entity_filtered = function(filters)
      calls = calls + 1
      if filters[1].filter == "item-to-place" then
        return {placed = {name = "placed"}}
      end
      assert(filters[1].filter == "building")
      return {scripted = {name = "scripted"}}
    end,
  }

  local builder = setmetatable({}, {__index = MuroWallBuilder})
  builder:ensure_prototype_categories()
  builder:ensure_prototype_categories()
  assert(calls == 2, "each prototype filter should run exactly once")
  assert(builder.player_placeable_prototypes.placed)
  assert(builder.building_prototypes.scripted)
  prototypes = previous_prototypes
end)

test("entity classifiers use prototype semantics", function()
  local builder = fake_builder({}, {
    placeable = {placed = {}},
    buildings = {scripted = {}},
  })
  local tree = fake_entity{name = "tree", type = "tree"}
  local rock = fake_entity{
    name = "rock", type = "simple-entity",
    prototype = {count_as_rock_for_filtered_deconstruction = true},
  }
  local decorative = fake_entity{
    name = "decorative", type = "simple-entity",
    prototype = {count_as_rock_for_filtered_deconstruction = false},
  }
  local placed = fake_entity{name = "placed", type = "future-type"}
  local scripted = fake_entity{name = "scripted", type = "future-type"}

  assert(builder:is_natural_obstacle(tree))
  assert(builder:is_natural_obstacle(rock))
  assert(not builder:is_natural_obstacle(decorative))
  assert(builder:is_player_placeable(placed))
  assert(not builder:is_player_placeable(scripted))
  assert(builder:is_building_obstacle(placed))
  assert(builder:is_building_obstacle(scripted))
end)

test("clearability follows drag mode and settings", function()
  local tree = fake_entity{name = "tree", type = "tree"}
  local machine = fake_entity{name = "machine", type = "future-type"}
  local builder = fake_builder({}, {placeable = {machine = {}}})

  assert(not builder:may_clear(tree))
  builder.mark_for_deconstruction = true
  assert(builder:may_clear(tree))
  assert(not builder:may_clear(machine))

  builder.destroying = true
  builder.mark_for_deconstruction = false
  assert(builder:may_clear(tree))
  assert(not builder:may_clear(machine))
  builder.destroy_buildings = true
  assert(builder:may_clear(machine))
end)

test("undo indices start a group and then merge into it", function()
  local builder = fake_builder({})
  assert(builder:next_undo_index() == builder.UNDO_NEW)
  assert(builder:next_undo_index() == builder.UNDO_LAST)
  assert(builder:next_undo_index() == builder.UNDO_LAST)
end)

test("failed deconstruction does not consume or cache the undo action", function()
  local machine = fake_entity{
    name = "unmineable-machine",
    type = "future-type",
    unit_number = 80,
    order_succeeds = false,
  }
  local builder = fake_builder({})
  assert(not builder:order_deconstruction_once(machine))
  assert(builder.undo_is_new)
  assert(not builder:order_deconstruction_once(machine))
  assert(machine.order_count() == 2)
end)

test("already marked entities do not consume this drag's undo group", function()
  local machine = fake_entity{
    name = "marked-machine",
    type = "future-type",
    unit_number = 81,
    already_marked = true,
  }
  local builder = fake_builder({})
  assert(builder:order_deconstruction_once(machine))
  assert(builder.undo_is_new)
  assert(machine.order_count() == 0)
end)

test("entities without unit numbers are deduplicated by name and bounds", function()
  local rock = fake_entity{
    name = "rock-huge",
    type = "simple-entity",
    prototype = {count_as_rock_for_filtered_deconstruction = true},
  }
  local builder = fake_builder({})
  assert(builder:order_deconstruction_once(rock))
  assert(builder:order_deconstruction_once(rock))
  assert(rock.order_count() == 1)
end)

test("normal ghost building clears trees when enabled", function()
  local tree = fake_entity{name = "tree-01", type = "tree"}
  local builder = fake_builder({tree}, {mark_natural = true})
  builder:place_wall_ghost({x = 0.5, y = 0.5})
  assert(tree.order_count() == 1)
  assert(builder.created_count() == 1)
  assert(builder.last_build_check().forced == true)
end)

test("non-rock simple entities are not treated as rocks", function()
  local simple = fake_entity{
    name = "decorative-simple",
    type = "simple-entity",
    prototype = {count_as_rock_for_filtered_deconstruction = false},
  }
  local builder = fake_builder({simple}, {mark_natural = true})
  builder:place_wall_ghost({x = 0.5, y = 0.5})
  assert(simple.order_count() == 0)
  assert(builder.created_count() == 0)
end)

test("reverse selection deconstructs modded placeable entities without ghosts", function()
  local machine = fake_entity{
    name = "mod-machine",
    type = "future-machine-type",
    unit_number = 42,
  }
  local builder = fake_builder({machine}, {
    destroying = true,
    destroy_buildings = true,
    placeable = {["mod-machine"] = {}},
  })
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(machine.order_count() == 1)
  assert(builder.created_count() == 0)
end)

test("reverse selection includes all four cursor-area edges", function()
  local top = fake_entity{
    name = "tree-top", type = "tree", unit_number = 101,
    bounding_box = box(2.1, 0.1, 2.9, 0.9),
  }
  local right = fake_entity{
    name = "tree-right", type = "tree", unit_number = 102,
    bounding_box = box(4.1, 2.1, 4.9, 2.9),
  }
  local bottom = fake_entity{
    name = "tree-bottom", type = "tree", unit_number = 103,
    bounding_box = box(2.1, 4.1, 2.9, 4.9),
  }
  local left = fake_entity{
    name = "tree-left", type = "tree", unit_number = 104,
    bounding_box = box(0.1, 2.1, 0.9, 2.9),
  }
  local builder = fake_builder({top, right, bottom, left}, {
    destroying = true,
  })
  local selected = builder:selection_area{
    area = box(0.5, 0.5, 4.5, 4.5),
    -- Simulate the half-open tile list that omits the cursor's final row and
    -- column even though the raw selection reaches their centers.
    tiles = {
      {position = {x = 0, y = 0}},
      {position = {x = 3, y = 3}},
    },
  }

  builder:deconstruct(selected, 1)

  assert(top.order_count() == 1)
  assert(right.order_count() == 1)
  assert(bottom.order_count() == 1)
  assert(left.order_count() == 1)
end)

test("reverse selection removes wall ghosts by default", function()
  local ghost = fake_entity{
    name = "entity-ghost",
    type = "entity-ghost",
    ghost_name = "stone-wall",
    ghost_type = "wall",
  }
  local builder = fake_builder({ghost}, {destroying = true})
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(ghost.order_count() == 1)
end)

test("reverse selection leaves non-wall ghosts when building destruction is off", function()
  local ghost = fake_entity{
    name = "entity-ghost",
    type = "entity-ghost",
    ghost_name = "assembling-machine-3",
    ghost_type = "assembling-machine",
  }
  local builder = fake_builder({ghost}, {
    destroying = true,
    placeable = {["assembling-machine-3"] = {}},
  })
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(ghost.order_count() == 0)
end)

test("reverse selection removes placeable entity ghosts with building destruction", function()
  local ghost = fake_entity{
    name = "entity-ghost",
    type = "entity-ghost",
    ghost_name = "mod-machine",
    ghost_type = "future-machine-type",
  }
  local builder = fake_builder({ghost}, {
    destroying = true,
    destroy_buildings = true,
    placeable = {["mod-machine"] = {}},
  })
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(ghost.order_count() == 1)
end)

test("reverse selection leaves non-placeable entity ghosts", function()
  local ghost = fake_entity{
    name = "entity-ghost",
    type = "entity-ghost",
    ghost_name = "script-building",
    ghost_type = "future-building-type",
  }
  local builder = fake_builder({ghost}, {
    destroying = true,
    destroy_buildings = true,
    buildings = {["script-building"] = {}},
  })
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(ghost.order_count() == 0)
end)

test("script-only buildings block but are not destroyed", function()
  local building = fake_entity{
    name = "script-building",
    type = "future-building-type",
    unit_number = 43,
  }
  local builder = fake_builder({building}, {
    destroying = true,
    destroy_buildings = true,
    buildings = {["script-building"] = {}},
  })
  builder:deconstruct(box(0, 0, 1, 1), 1)
  assert(building.order_count() == 0)
  assert(builder.created_count() == 0)
end)

test("multi-tile entities receive one deconstruction order", function()
  local machine = fake_entity{
    name = "large-mod-machine",
    type = "future-machine-type",
    unit_number = 44,
    bounding_box = box(0, 0, 2, 1),
  }
  local builder = fake_builder({machine}, {
    destroying = true,
    destroy_buildings = true,
    placeable = {["large-mod-machine"] = {}},
  })
  builder:deconstruct(box(0, 0, 2, 1), 1)
  assert(machine.order_count() == 1)
end)

test("transient entities do not leave wall gaps", function()
  local character = fake_entity{name = "character", type = "character"}
  local builder = fake_builder({character})
  builder:place_wall_ghost({x = 0.5, y = 0.5})
  assert(character.order_count() == 0)
  assert(builder.created_count() == 1)
  assert(builder.last_build_check().forced == false)
end)

print(string.format("All %d tests passed", tests_run))
