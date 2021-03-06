local Draw = require("api.Draw")
local Gui = require("api.Gui")
local Ui = require("api.Ui")

local IInput = require("api.gui.IInput")
local IUiLayer = require("api.gui.IUiLayer")
local InputHandler = require("api.gui.InputHandler")
local UiTheme = require("api.gui.UiTheme")

local DirectionPrompt = class.class("DirectionPrompt", IUiLayer)

DirectionPrompt:delegate("input", IInput)

function DirectionPrompt:init(x, y)
   self.center_x = x
   self.center_y = y
   self.frame = 0
   self.cardinal = true
   self.result = nil
   self.canceled = false

   self.input = InputHandler:new()
   self.input:bind_keys(self:make_keymap())
end

function DirectionPrompt:make_keymap()
   return {
      enter = function()
         self.result = "Center"
      end,
      north = function()
         if self.cardinal then
            self.result = "North"
         end
      end,
      south = function()
         if self.cardinal then
            self.result = "South"
         end
      end,
      west = function()
         if self.cardinal then
            self.result = "West"
         end
      end,
      east = function()
         if self.cardinal then
            self.result = "East"
         end
      end,
      escape = function()
         self.canceled = true
      end,
      cancel = function()
         self.canceled = true
      end
   }
end

function DirectionPrompt:relayout()
   self.x, self.y = Gui.tile_to_screen(self.center_x, self.center_y)
   self.tile_width, self.tile_height = Draw.get_coords():get_size()
   self.t = UiTheme.load(self)
end

function DirectionPrompt:on_query()
   Gui.play_sound("base.pop2")
end

function DirectionPrompt:draw()
   local frame = math.floor(self.frame*50)
   local alpha = math.floor(200 - frame / 2 % 20 * (frame / 2 % 20))
   local draw_x, draw_y, scx, scy = Gui.field_draw_pos()
   local sx, sy = Draw.get_coords():get_start_offset(draw_x, draw_y)
   local tw, th = Draw.get_coords():get_size()
   local x = self.x - draw_x + sx + math.floor(tw / 2)
   local y = self.y - draw_y + sy + math.floor(th / 2)

   -- TODO move draw args into params

   Draw.set_color({255,255,255,alpha})

   if self.cardinal then
      self.t.direction_arrow:draw(x, y - self.tile_height, nil, nil, nil, true, 0)
      self.t.direction_arrow:draw(x, y + self.tile_height, nil, nil, nil, true, 180)
      self.t.direction_arrow:draw(x + self.tile_width, y, nil, nil, nil, true, 90)
      self.t.direction_arrow:draw(x - self.tile_width, y, nil, nil, nil, true, 270)
   end

   self.t.direction_arrow:draw(x - self.tile_width, y - self.tile_height, nil, nil, nil, true, 315)
   self.t.direction_arrow:draw(x + self.tile_width, y + self.tile_height, nil, nil, nil, true, 135)
   self.t.direction_arrow:draw(x + self.tile_width, y - self.tile_height, nil, nil, nil, true, 45)
   self.t.direction_arrow:draw(x - self.tile_width, y + self.tile_height, nil, nil, nil, true, 225)
end

function DirectionPrompt:update(dt)
   self.frame = self.frame + dt

   if self.canceled then
      return nil, "canceled"
   end

   if self.result then
      return self.result
   end
end

return DirectionPrompt
