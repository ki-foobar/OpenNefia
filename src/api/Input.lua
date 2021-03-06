-- Functions for receiving input from the player.
--- @module Input

local Chara = require("api.Chara")
local Map = require("api.Map")
local Pos = require("api.Pos")
local Log = require("api.Log")
local config = require("internal.config")
local data = require("internal.data")
local draw = require("internal.draw")
local input = require("internal.input")

local Prompt = require("api.gui.Prompt")
local TextPrompt = require("api.gui.TextPrompt")
local NumberPrompt = require("api.gui.NumberPrompt")
local DirectionPrompt = require("api.gui.DirectionPrompt")
local PositionPrompt = require("api.gui.PositionPrompt")
local MorePrompt = require("api.gui.MorePrompt")

local Input = {}

Input.set_key_handler = input.set_key_handler
Input.set_mouse_handler = input.set_mouse_handler

function Input.prompt(choices)
   return Prompt:new(choices):query()
end

--- Opens a dialog prompt asking for a yes or no response. Returns
--- true if "yes" was selected.
---
--- @treturn bool
function Input.yes_no()
   local res = Input.prompt({{ text = "ui.yes", key = "y" }, { text = "ui.no", key = "n" }})
   return res.index == 1
end

--- Queries the player for text input.
---
--- @tparam[opt] int length The length of the text box in characters. Defaults to 16.
--- @tparam[opt] bool can_cancel True if the cancellation is allowed. Defaults to true.
--- @tparam[opt] bool limit_length True if the maximum text enterable is limited. Defaults to true.
--- @treturn[opt] string the text that was input
--- @treturn[opt] string "canceled" if prompt was canceled
function Input.query_text(length, can_cancel, limit_length)
   return TextPrompt:new(length, can_cancel, limit_length):query()
end

--- Queries the player for number input.
---
--- @tparam[opt] int max The maximum number enterable. Defaults to 100.
--- @tparam[opt] int initial The initial number. Defaults to `max`.
--- @treturn[opt] int the number that was input
--- @treturn[opt] string "canceled" if prompt was canceled
function Input.query_number(max, initial)
   return NumberPrompt:new(max, initial):query()
end

local function query_inventory(chara, operation, params, returns_item, group)
   local InventoryWrapper = require("api.gui.menu.InventoryWrapper")

   operation = operation or "elona.inv_examine"

   params = params or {}
   params.chara = chara
   params.map = chara and chara:current_map()
   params.target = params.target or nil

   local result, canceled = InventoryWrapper:new(operation, params, returns_item, group):query()

   return result, canceled
end

--- Halts input and displays the "More..." popup.
function Input.query_more()
   MorePrompt:new():query()
end

--- Queries a character to run an inventory operation. This will run
--- the associated selection action in the inventory context if an
--- item is selected, and may return accordingly.
---
--- @tparam IChara chara
--- @tparam id:elona_sys.inventory_proto operation
--- @tparam[opt] table params
--- @tparam[opt] id:elona_sys.inventory_group group Inventory group
---              the operation belongs to for menu cycling. The
---              operation must be contained in the group.
--- @treturn[opt] turn_result
--- @treturn[opt] string "canceled" if the prompt was canceled
function Input.query_inventory(chara, operation, params, group)
   -- TODO: this can get confusing because not all contexts
   -- necessarily receive a character, and besides the "chara" field
   -- is treated specially in some parts. The interface should be
   -- uniform between this and Input.activate_shortcut.
   return query_inventory(chara, operation, params, false, group)
end

--- Queries for an item in a character's inventory according to the
--- rules of the provided inventory operation. Instead of running the
--- defined selection action when an item is selected, the selected
--- item is returned.
---
--- @tparam IChara chara
--- @tparam id:elona_sys.inventory_proto operation
--- @tparam[opt] table params
--- @treturn[opt] IItem
--- @treturn[opt] string "canceled" if the prompt was canceled
function Input.query_item(chara, operation, params)
   return query_inventory(chara, operation, params, true)
end

--- Queries the player for a direction.
---
--- @tparam[opt] IChara chara Defaults to the player.
--- @treturn[opt] direction
--- @treturn[opt] string error
function Input.query_direction(chara)
   chara = chara or Chara.player()
   local result, canceled = DirectionPrompt:new(chara.x, chara.y):query()
   if canceled then
      return result, canceled
   end

   local x, y = Pos.add_direction(result, chara.x, chara.y)
   if not Map.is_in_bounds(x, y, chara:current_map()) then
      return nil, "out_of_bounds"
   end

   return result
end

--- Queries the player for a position.
---
--- @tparam[opt] IChara chara Defaults to the player.
--- @treturn[opt] int x
--- @treturn[opt] int y
--- @treturn[opt] string error
function Input.query_position(chara)
   chara = chara or Chara.player()
   local result, canceled = PositionPrompt:new(chara.x, chara.y):query()
   if canceled then
      return result, canceled
   end

   return result.x, result.y
end

function Input.reload_keybinds()
   Log.info("Reloading keybinds.")

   local kbs = config["base.keybinds"]
   for _, kb in data["base.keybind"]:iter() do
      local id = kb._id

      -- allow omitting "base." if the keybind is provided by the base
      -- mod.
      if string.match(id, "^base%.") then
         id = string.split(id, ".")[2]
      end

      if kbs[id] == nil then
         kbs[id] = {
            primary = kb.default,
            alternate = kb.default_alternate,
         }
      end
   end

   local layer = draw.get_current_layer()
   if layer then
      layer.layer:focus()
   end
end

function Input.back_to_field()
   local layers = table.set {
      "MainHud",
      "field_layer",
      "MainTitleMenu"
   }
   while not layers[draw.get_current_layer().layer.__class.__name] do
      draw.pop_layer()
   end
end

function Input.halt_input()
   draw.get_current_layer().layer:halt_input()
end

function Input.enqueue_macro(keybind)
   return draw.get_current_layer().layer:enqueue_macro(keybind)
end

function Input.clear_macro_queue()
   draw.get_current_layer().layer:clear_macro_queue()
end

return Input
