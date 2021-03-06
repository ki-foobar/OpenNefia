local Chara = require("api.Chara")
local Gui = require("api.Gui")
local Rand = require("api.Rand")

local element = {
   {
      _id = "fire",
      elona_id = 50,
      color = { 255, 155, 155 },
      ui_color = { 150, 0, 0 },
      can_resist = true,
      sound = "base.atk_fire",

      on_modify_damage = function(chara, damage)
         if chara:has_effect("elona.wet") then
            damage = damage / 3
         end

         return damage
      end,

      on_damage_tile = function(self, x, y)
      end,

      on_damage = function(chara, damage)
         if not chara:has_effect("elona.wet") then
            Gui.mes("Mef add fire")
         end
      end,

      on_kill = function(chara, damage)
         if not chara:has_effect("elona.wet") then
            Gui.mes("Mef add fire")
         end
      end
   },
   {
      _id = "cold",
      elona_id = 51,
      color = { 255, 255, 255 },
      ui_color = { 0, 0, 150 },
      sound = "base.atk_ice",

      on_damage_tile = function(self, x, y)
      end,
   },
   {
      _id = "lightning",
      elona_id = 52,
      color = { 255, 255, 175 },
      ui_color = { 150, 150, 0 },
      can_resist = true,
      sound = "base.atk_elec",

      on_modify_damage = function(chara, damage)
         if chara:has_effect("elona.wet") then
            damage = damage * 3 / 2
         end

         return damage
      end,

      on_damage = function(chara)
         local chance = 3
         if chara.quality >= 4 then -- miracle
            chance = chance + 3
         end
         if Rand.one_in(chance) then
            chara:apply_effect("elona.paralysis", 1)
         end
      end
   },
   {
      _id = "darkness",
      elona_id = 53,
      color = { 175, 175, 255 },
      ui_color = { 100, 80, 80 },
      can_resist = true,
      sound = "base.atk_dark",

      on_damage = function(chara, params)
         chara:apply_effect("elona.blindness",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "mind",
      elona_id = 54,
      color = { 255, 195, 185 },
      ui_color = { 150, 100, 50 },
      can_resist = true,
      preserves_sleep = true,
      sound = "base.atk_mind",

      on_damage = function(chara, params)
         chara:apply_effect("elona.confusion",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "nether",
      elona_id = 56,
      color = { 155, 154, 153 },
      ui_color = { 150, 50, 0 },
      can_resist = true,
      sound = "base.atk_hell",

      after_apply_damage = function(chara, params)
         Gui.mes("after")
         local damage = params.damage
         if params.source and damage > 0 then
            params.source:heal_hp(
               math.clamp(
                  Rand.rnd(
                     damage * (
                        150 + params.element_power * 2) / 1000 + 10), 1, params.source:calc(
                     "max_hp") / 10 + Rand.rnd(5)))
         end
      end,

      on_kill = function(chara, params)
         local damage = params.damage
         if not Chara.is_alive(chara) then
            params.source:heal_hp(Rand.rnd(damage * (200 + params.element_power) / 1000 + 5))
         end
      end
   },
   {
      _id = "poison",
      elona_id = 55,
      color = { 175, 255, 175 },
      ui_color = { 0, 150, 0 },
      can_resist = true,
      sound = "base.atk_poison",

      on_damage = function(chara, params)
         chara:apply_effect("elona.poison",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "sound",
      elona_id = 57,
      color = { 235, 215, 155 },
      ui_color = { 50, 100, 150 },
      can_resist = true,
      sound = "base.atk_sound",

      on_damage = function(chara, params)
         chara:apply_effect("elona.confusion",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "chaos",
      elona_id = 59,
      color = { 185, 155, 215 },
      ui_color = { 150, 0, 150 },
      can_resist = true,
      preserves_sleep = true,
      sound = "base.atk_chaos",

      on_damage = function(chara, params)
         local elep = params.element_power
         local power = function()
            return Rand.rnd(elep / 3 * 2 + 1)
         end

         if Rand.rnd(10) < elep / 75 + 4 then
            chara:apply_effect("elona.blind", power())
         end
         if Rand.rnd(20) < elep / 50 + 4 then
            chara:apply_effect("elona.paralysis", power())
         end
         if Rand.rnd(20) < elep / 50 + 4 then
            chara:apply_effect("elona.confusion", power())
         end
         if Rand.rnd(20) < elep / 50 + 4 then
            chara:apply_effect("elona.poison", power())
         end
         if Rand.rnd(20) < elep / 50 + 4 then
            chara:apply_effect("elona.sleep", power())
         end
      end,
   },
   {
      _id = "nerve",
      elona_id = 58,
      color = { 155, 205, 205 },
      ui_color = { 100, 150, 50 },
      can_resist = true,
      preserves_sleep = true,
      sound = "base.atk_nerve",

      on_damage = function(chara, params)
         chara:apply_effect("elona.paralysis",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "magic",
      elona_id = 60,
      ui_color = { 150, 100, 100 },
      can_resist = true,

      calc_initial_resist_level = function(chara, level)
         if level < 500 then
            return 100
         end
         return level
      end
   },
   {
      _id = "cut",
      elona_id = 61,

      on_damage = function(chara, params)
         chara:apply_effect("elona.bleeding",
                            Rand.rnd(params.element_power + 1))
      end
   },
   {
      _id = "ether",
      elona_id = 62,

      on_damage = function(chara)
         print("ether")
      end
   },
   {
      _id = "acid",
      color = { 175, 255, 175 },
      elona_id = 63,
      sound = "base.atk_poison",
   },
   {
      _id = "hunger",
      elona_id = 614,
   },
   {
      _id = "rotten",
      elona_id = 613,
   },
   {
      _id = "fear",
      elona_id = 617,
   },
   {
      _id = "soft",
      elona_id = 618,
   },
   {
      _id = "vorpal",
      elona_id = 658,
   },
}

data:add_multi("base.element", element)
