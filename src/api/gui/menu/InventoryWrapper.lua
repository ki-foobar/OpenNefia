local Draw = require("api.Draw")
local Gui = require("api.Gui")
local I18N = require("api.I18N")

local IInput = require("api.gui.IInput")
local IUiLayer = require("api.gui.IUiLayer")
local IconBar = require("api.gui.menu.IconBar")
local InputHandler = require("api.gui.InputHandler")
local InventoryContext = require("api.gui.menu.InventoryContext")
local InventoryMenu = require("api.gui.menu.InventoryMenu")
local UiTheme = require("api.gui.UiTheme")
local data = require("internal.data")

--- Wraps an InventoryMenu such that multiple inventory actions can be
--- switched between by pressing Tab. A single InventoryMenu will
--- handle a single action, like getting or eating, and this class
--- aggregates them all and shows an IconBar to display the current
--- action.
local InventoryWrapper = class.class("InventoryWrapper", IUiLayer)

InventoryWrapper:delegate("input", IInput)

function InventoryWrapper:init(proto_id, params, returns_item, group_id)
   self.x = 0
   self.y = 0
   self.width = Draw.get_width()
   self.height = Draw.get_height()
   self.params = params
   self.returns_item = returns_item
   if self.returns_item == nil then
      self.returns_item = false
   end

   self.input = InputHandler:new()
   self.input:bind_keys(self:make_keymap())
   self.submenu = nil
   self.icon_bar = IconBar:new("inventory_icons")

   if group_id then
      self.group = data["elona_sys.inventory_group"]:ensure(group_id)

      local icon_order = fun.iter(self.group.protos)
         :map(function(id)
               local proto = data["elona_sys.inventory_proto"]:ensure(id)
               if proto.icon == nil then
                  error(("Inventory prototype '%s' must have an icon to appear in a menu group"):format(proto._id))
               end
               return {
                  icon = proto.icon+1,
                  text = I18N.get(proto.text)
               }
             end)
         :to_list()
      self.icon_bar:set_data(icon_order)
      self.menu_count = #icon_order

      if proto_id == nil then
         proto_id = self.group.protos[1]
      end

      self.selected_index = fun.iter(self.group.protos):index(proto_id)
      if self.selected_index == nil then
         error(("Inventory prototype '%s' must be contained in inventory group '%s'")
               :format(proto_id, self.group._id))
      end
   end

   self.proto_id = proto_id

   self:switch_context()
end

function InventoryWrapper:make_keymap()
   return {
      previous_page = function() self:previous_menu() end,
      next_page = function() self:next_menu() end,
      raw_ctrl_tab = function() self:previous_menu() end,
      raw_tab = function() self:next_menu() end,
   }
end

function InventoryWrapper:next_menu()
   if self.group == nil then
      return
   end

   self.selected_index = self.selected_index + 1
   if self.selected_index > self.menu_count then
      self.selected_index = 1
   end

   self:switch_context()
end

function InventoryWrapper:previous_menu()
   if self.group == nil then
      return
   end

   self.selected_index = self.selected_index - 1
   if self.selected_index < 1 then
      self.selected_index = self.menu_count
   end

   self:switch_context()
end

function InventoryWrapper:switch_context()
   Gui.play_sound("base.inv")

   local proto_id
   if self.group then
      proto_id = self.group.protos[self.selected_index]
   else
      proto_id = self.proto_id
   end
   local proto = data["elona_sys.inventory_proto"]:ensure(proto_id)

   local ctxt = InventoryContext:new(proto, self.params)
   self.submenu = InventoryMenu:new(ctxt, self.returns_item)
   self.input:forward_to(self.submenu)

   if self.group then
      self.icon_bar:select(self.selected_index)
   end

   self.submenu:relayout(self.x, self.y, self.width, self.height)

   -- HACK
   collectgarbage()
end

function InventoryWrapper:relayout(x, y, width, height)
   self.x = x or 0
   self.y = y or 0
   self.width = width or Draw.get_width()
   self.height = height or Draw.get_height()
   self.t = UiTheme.load(self)

   if self.group then
      self.icon_bar:relayout(self.width - (44 * self.menu_count + 60), 34, 44 * self.menu_count + 40, 22)
   end

   self.submenu:relayout(self.x, self.y, self.width, self.height)
end

function InventoryWrapper:draw()
   Draw.set_color(255, 255, 255)
   if self.group then
      self.icon_bar:draw()
   end
   self.submenu:draw()
end

function InventoryWrapper:update()
   local result, canceled = self.submenu:update()
   if canceled then
      return nil, "canceled"
   elseif result then
      return result
   end

   if self.canceled then
      return nil, "canceled"
   end
end

function InventoryWrapper:release()
   self.icon_bar:release()
end

return InventoryWrapper
