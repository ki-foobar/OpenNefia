local Feat = require("api.Feat")
local Chara = require("api.Chara")
local Itemgen = require("mod.tools.api.Itemgen")
local Charagen = require("mod.tools.api.Charagen")
local Map = require("api.Map")
local InstancedMap = require("api.InstancedMap")
local Rand = require("api.Rand")
local Filters = require("mod.elona.api.Filters")
local Calc = require("mod.elona.api.Calc")
local Log = require("api.Log")
local MapTileset = require("mod.elona_sys.map_tileset.api.MapTileset")

data:add_type {
   name = "dungeon_template",
   schema = schema.Record {
      generator = schema.Function
   }
}

data:add_multi(
   "base.map_tile",
   {
      {
         _id = "mapgen_floor",
         image = "graphic/default/floor.png",
         is_solid = true
      },
      {
         _id = "mapgen_tunnel",
         image = "graphic/default/floor.png",
         is_solid = false
      },
      {
         _id = "mapgen_wall",
         image = "graphic/default/floor.png",
         is_solid = true
      },
      {
         _id = "mapgen_room",
         image = "graphic/default/floor.png",
         is_solid = false
      },
      {
         _id = "mapgen_floor_2",
         image = "graphic/default/floor.png",
         is_solid = false
      },
})

data:add {
   _type = "base.feat",
   _id = "mapgen_block",

   is_solid = true,
   is_opaque = true
}

local function tag_stairs(map)
   local pred

   pred = function(feat) return feat._id == "elona.stairs_down" end
   local down = map:iter_feats():filter(pred):nth(1)

   if down then
      down.label = "stairs_down"
   end

   pred = function(feat) return feat._id == "elona.stairs_up" end
   local up = map:iter_feats():filter(pred):nth(1)
   if up then
      up.label = "stairs_up"
   end
end

local function generate_dungeon_raw(template, gen_params, opts)
   local rooms = {}

   local map, err
   local tries = 0
   while true do
      map, err = template.generate(rooms, gen_params, opts)
      if not map then
         return nil, err
      end

      if type(map) == "string" then
         assert(type(err) == "table", "Generation parameters should be the second return value.")
         if tries > 10 then
            return nil, "More than 10 dungeon generators were composed together."
         end
         template = data["elona.dungeon_template"]:ensure(map)
         gen_params = err
      else
         break
      end

      tries = tries + 1
   end

   class.assert_is_an(InstancedMap, map)
   map.rooms = rooms

   return map
end

local function set_filter(dungeon)
   -- TODO support custom filters
   local filter = {
      level = Calc.calc_object_level(dungeon:calc("dungeon_level"), dungeon),
      quality = Calc.calc_object_quality(1),
   }

   if filter.level > 5 then
      ---pause()
   end

   return filter
end

local function populate_rooms(dungeon, template, gen_params)
   local has_monster_house = false

   for _, room in ipairs(dungeon.rooms) do
      local x = room.x + 1
      local y = room.y + 1
      local w = room.width - 2
      local h = room.height - 2
      local size = w * h

      for i=1, Rand.rnd(math.floor(size / 8) + 2) do
         if Rand.one_in(2) then
            Itemgen.create(Rand.rnd(w) + x,
                           Rand.rnd(h) + y,
                           {
                              level=dungeon.dungeon_level,
                              quality=1,
                              categories={Filters.dungeon()}
                           },
                           dungeon)
         end

         local filter = set_filter(dungeon)

         local chara = Charagen.create(Rand.rnd(w) + x, Rand.rnd(h) + y, filter, dungeon)
         if chara then
            if dungeon.dungeon_level > 3 then
               if (chara.proto.creaturepack or 0) > 0 then
                  if Rand.one_in(gen_params.creature_packs * 5 + 5) then
                     gen_params.creature_packs = gen_params.creature_packs + 1
                     for _=1, 10 + Rand.rnd(20) do
                        local filter2 = { level = chara.level, quality = Calc.calc_object_quality(1) }
                        Charagen.create(Rand.rnd(w) + x, Rand.rnd(h) + y, filter2, dungeon)
                     end
                     break
                  end
               end
            end
         end
      end

      if not (room.has_stairs_up or room.has_stairs_down) then
         if not has_monster_house or template.has_monster_houses then
            if Rand.one_in(8) and size < 40 then
               has_monster_house = true
               room.has_monster_house = true

               for ry = y, y + h - 1 do
                  for rx = x, x + w - 1 do
                     local filter = set_filter(dungeon)
                     Charagen.create(rx, ry, filter, dungeon)
                  end
               end

               if not template.has_monster_houses then
                  for _=1, Rand.rnd(3) + 1 do
                     Itemgen.create(Rand.rnd(w) + x, Rand.rnd(h) + y, {categories={"elona.container"}}, dungeon)
                  end
               end
            end
         end
      end
   end
end

local function place_trap(x, y, level, map)
   -- print "trap"
end

local function place_web(x, y, level, map)
   -- print "web"
end

local function place_pot(x, y, map)
   local dx, dy
   for _=1, 3 do
      if x == nil then
         dx = Rand.rnd(map:width() - 5) + 2
         dy = Rand.rnd(map:height() - 5) + 2
      else
         dx = x
         dy = y
      end
      if Map.is_floor(dx, dy, map) and Feat.at(dx, dy, map):length() == 0 then
         Feat.create("elona.pot", dx, dy, {}, map)
         return true
      end
   end

   return false
end

local function generate_dungeon(self, params, opts)
   local dungeon
   local template = data["elona.dungeon_template"]:ensure(params.id)
   Log.debug("generate dungeon: %s", inspect(params))

   local dungeon_level = params.dungeon_level or params.start_dungeon_level or 1
   local deepest_dungeon_level = params.deepest_dungeon_level
   local gen_params

   local area
   if opts.area_uid then
      local areas = save.base.area_mapping
      area = areas:area(opts.area_uid)
      deepest_dungeon_level = area.data.deepest_dungeon_level or deepest_dungeon_level
   end

   if deepest_dungeon_level == nil then
      deepest_dungeon_level = template.deepest_dungeon_level or 1
   end

   assert(dungeon_level)
   assert(deepest_dungeon_level, "Can't find deepest dungeon level")

   if area and not area.data.deepest_dungeon_level then
      area.data.deepest_dungeon_level = deepest_dungeon_level
      Log.debug("Setting area %d's deepest level: %d", area.uid, deepest_dungeon_level)
   end

   local attempts = params.attempts or 2000
   for _ = 1, attempts do
      local width = params.width or 34 + Rand.rnd(15)
      local height = params.height or 22 + Rand.rnd(15)

      gen_params = {
         width = width,
         height = height,
         room_count = width * height / 70,
         min_size = 3,
         max_size = 4,
         extra_room_count = 10,
         room_entrance_count = 1,
         tunnel_length = width * height,
         hidden_path_chance = 5,
         creature_packs = 1,
         dungeon_level = dungeon_level,
         deepest_dungeon_level = deepest_dungeon_level,
         max_crowd_density = width * height / 100
      }

      local err
      dungeon, err = generate_dungeon_raw(template, gen_params, opts)

      if dungeon then
         params = table.merge(gen_params, params)
         break
      end
   end

   if dungeon == nil then
      return nil, ("Dungeon generation failed for '%s'."):format(params.id)
   end

   Log.info("Dungeon generated: %s", params.id)

   local tileset = params.tileset or "elona.dirt"
   MapTileset.apply(tileset, dungeon)

   dungeon.dungeon_level = dungeon_level
   dungeon.deepest_dungeon_level = deepest_dungeon_level
   assert(dungeon.dungeon_level)
   assert(dungeon.deepest_dungeon_level)

   tag_stairs(dungeon)

   data["elona.dungeon_template"]:ensure(params.id)

   Log.info("Populating dungeon rooms.")
   populate_rooms(dungeon, template, gen_params)

   -- TODO: this is annoying. the density parameter is in "copy" on
   -- map templates but it has to be passed to the dungeon template
   -- instead.
   local crowd_density = dungeon:calc("max_crowd_density")
   local mob_density, item_density = crowd_density / 4, crowd_density / 4

   if template.calc_density then
      local result = template.calc_density(dungeon)
      mob_density = result.mob
      item_density = result.item
   end

   -- HACK: Block the starting positions so nothing gets generated
   -- there. This was done in Elona by just placing the player on the
   -- stairs in the map during the generation routine.

   local blocks = {}
   for _, feat in Feat.iter(dungeon) do
      if feat._id == "elona.stair_up" or feat._id == "elona.stair_down" then
         blocks[#blocks+1] = assert(Feat.create("elona.mapgen_block", feat.x, feat.y, {}, dungeon))
         assert(not Map.can_access(feat.x, feat.y, dungeon))
      end
   end

   if template.after_generate then
      template.after_generate(dungeon)
   end

   -- TODO generation can be special per room type

   Log.info("Map density: %s", crowd_density)

   Log.info("Creating %d mobs.", mob_density)
   for _=1, mob_density do
      Charagen.create(nil, nil, set_filter(dungeon), dungeon)
   end

   Log.info("Creating %d items.", item_density)
   for _=1, item_density do
      Itemgen.create(nil, nil,
                     {
                        level = dungeon.dungeon_level,
                        quality = 1,
                        categories = {Filters.dungeon()}
                     },
                     dungeon)
   end

   ---

   Log.info("Placing traps.")
   for _=0, Rand.rnd(dungeon:width() * dungeon:height() / 80) do
      place_trap(0, 0, dungeon.dungeon_level, dungeon)
   end

   if Rand.one_in(5) then
      local n = Rand.rnd(dungeon:width() * dungeon:height() / 40)
      if Rand.one_in(5) then
         n = Rand.rnd(dungeon:width() * dungeon:height() / 5)
      end
      for _=1, n do
         place_web(0, 0, dungeon.dungeon_level * 10 + 100, dungeon)
      end
   end

   if Rand.one_in(4) then
      local n = math.clamp(Rand.rnd(dungeon:width() * dungeon:height() / 500 + 1) + 1, 3, 15)
      for _=1, n do
         place_pot(nil, nil, dungeon)
      end
   end

   if not dungeon.is_temporary then
      local kill_count = 0
      if Rand.one_in(15 + kill_count * 2) then
         Chara.create("elona.little_sister")
      end
   end

   for _, block in ipairs(blocks) do
      block:remove_ownership()
   end

   dungeon.can_exit_from_edge = false

   local gen_id = string.format("%s_%d_%d", params.id, dungeon_level, deepest_dungeon_level)

   Log.info("Generation finished: %d %s", dungeon.uid, gen_id)

   return dungeon, gen_id
end

data:add {
   _type = "base.map_generator",
   _id = "dungeon_template",

   params = {
      id = "string",
      width = "number",
      height = "number",
      start_dungeon_level = "number",
      dungeon_level = "number[opt]",
      deepest_dungeon_level = "number",
      area_id = "string"
   },

   connect_stairs = true,

   generate = generate_dungeon,

   almost_equals = table.deepcompare
}
