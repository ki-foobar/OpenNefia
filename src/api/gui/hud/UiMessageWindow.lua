local Draw = require("api.Draw")
local IUiElement = require("api.gui.IUiElement")
local UiTheme = require("api.gui.UiTheme")
local circular_buffer = require("thirdparty.circular_buffer")

local UiMessageWindow = class("UiMessageWindow", IUiElement)

function UiMessageWindow:init()
   self.width = 800
   self.height = 72

   self.max_log = 200
   self.history = circular_buffer:new(self.max_log)
   self.max_lines = 4
   self.each_line = circular_buffer:new(self.max_lines)

   self.y_offset = 0
   self.current_width = 0
   self.canvas = nil
   self.redraw = true

   self:recalc_lines()
end

function UiMessageWindow:relayout(x, y, width, height)
   if self.canvas == nil or width ~= self.width or height ~= self.height then
      self.canvas = love.graphics.newCanvas(width, height)
      self.redraw = true
   end

   self.x = x
   self.y = y
   self.width = width
   self.height = height
   self.t = UiTheme.load(self)
   self.cutoff = { text = "" }
   self.first_index = 1
   self.the_width = 0

   Draw.set_font(14) -- 14 - en * 2
   self.max_lines = math.floor(self.height / Draw.text_height()) - 1
   self.y_offset = -(self.height % Draw.text_height())

   self:recalc_lines()
end

function UiMessageWindow:draw_one_text(text, color, x, y)
   local max_width, wrapped = Draw.wrap_text(text, self.width - self.the_width)
   Draw.text(wrapped[1], x, y)
   self.the_width = self.the_width + Draw.text_width(wrapped[1])
   x = self.the_width
   local width_remain = self.width - self.the_width

   if #wrapped > 1 then
      local rest = string.strip_prefix(text, wrapped[1])
      self.the_width = 0
      max_width, wrapped = Draw.wrap_text(rest, self.width - self.the_width)
      for i=1,#wrapped do
         x = 0
         y = y + Draw.text_height()
         Draw.text(wrapped[i], x, y)
         self.the_width = self.the_width + Draw.text_width(wrapped[1])
         x = self.the_width
      end
   end

   return x, y
end

function UiMessageWindow:push_text(text, color)
   -- NOTE: The global font has to be set now for the text width
   -- calculation to be correct.
   Draw.set_font(14) -- 14 - en * 2
   color = color or {255, 255, 255}

   if self.each_line:len() == 0 then
      self.each_line:push({text = {}, width = 0})
   end

   local first = self.each_line[1]
   local work = ""

   -- HACK: love2d's text wrapping doesn't work with CJK, because it
   -- uses the last position of an ASCII halfwidth character to do
   -- wrapping. But this solution is really inefficient...
   for _, s in utf8.chars(text) do
      -- TODO: handle halfwidth text wrapping (English)
      local width = Draw.text_width(s)
      if first.width + width > self.width then
         first.text[#first.text+1] = {color = color, text = work, width = Draw.text_width(work)}
         self.each_line:push({text = {}, width = 0})
         first = self.each_line[1]
         work = ""
      end

      work = work .. s
      first.width = first.width + width
   end

   first.text[#first.text+1] = {color = color, text = work, width = Draw.text_width(work)}
end

function UiMessageWindow:draw_one_line(x, y, line)
   for _, item in ipairs(line.text) do
      -- love.graphics.print() accepts arguments like
      --   {color, text, color, text...}
      Draw.set_color(item.color)
      Draw.text(item.text, x, y)
      x = x + item.width
   end
end

-- Find the index of the first text fragment that will fully appear in
-- the message window and the partially wrapped text of the text
-- fragment before it.
--
-- /This line is off-screen. Previous  \
-- +-----|-----------------|-----------+
-- |text.|This is the text.|Other text.|
-- +-----|-----------------|-----------+
--  ^^^^^|^^^^^^^^^^^^^^^^^|
--    \              \
--     \____cutoff    \______index_of_first_text
--
function UiMessageWindow:calc_start_offset()
   -- NOTE: The global font has to be set now for the text width
   -- calculation to be correct.
   Draw.set_font(14) -- 14 - en * 2

   local width_remain = self.width
   local lines = 0
   local cutoff = ""
   local index_of_first_text = self.history:len()
   local found

   -- start from the most recent text fragment and wrap text backwards
   -- (bottom of message window to top) until the wrapped line
   -- overflows into the offscreen portion of the message window. The
   -- overflowed text that can fit into the visible message window
   -- area is the text to print at the beginning of the message
   -- window.
   for i=1,self.history:len() do
      local t = self.history[i]
      local text = t.text
      cutoff = text
      local tw = Draw.text_width(text)
      while tw > width_remain do
         -- Amount of width (in pixels) the text goes over by.
         local diff = tw - width_remain

         width_remain = self.width - tw

         local max_width, wrapped = Draw.wrap_text(t.text, diff)

         -- Text that fit in the previous line before wrapping.
         local first = wrapped[1]

         -- The text that overflowed into the next line.
         local rest = wrapped[2]

         lines = lines + 1
         text = first
         found = rest
         tw = Draw.text_width(text)
         if lines > 3 then
            break
         end
      end
      width_remain = width_remain - tw
      if lines > 3 then
         index_of_first_text = i
         cutoff = found
         break
      end
   end

   return cutoff, index_of_first_text
end

function UiMessageWindow:recalc_lines()
   print("recalc",self.history:len(),self.each_line:len())
   if self.history:len() == 0 then
      return
   end

   local cutoff, index_of_first_text = self:calc_start_offset()

   print("clearm",index_of_first_text)

   self.each_line = circular_buffer:new(self.max_lines)

   for i=index_of_first_text,1,-1 do
      local t = self.history[i]
      _p(t)
      self:push_text(t.text, t.color)
   end
end

function UiMessageWindow:draw()
   Draw.set_color(255, 255, 255)

   Draw.image(self.canvas, self.x, self.y)
   if not self.redraw then
      return
   end

   Draw.with_canvas(
      self.canvas,
      function()
         Draw.clear()

         self.t.message_window:draw_bar(0, 0, self.width)

         self.the_width = 0

         Draw.set_font(14) -- 14 - en * 2
         local x = 6
         local y = 5 + (self.each_line:len() - 1) * Draw.text_height()
         for i=1,self.each_line:len() do
            local line = self.each_line[i]
            self:draw_one_line(x, y, line)
            y = y - Draw.text_height()
         end

   end)

   self.redraw = false
end

function UiMessageWindow:newline()
   self.current_width = 0
end

function UiMessageWindow:message(text, color)
   text = tostring(text)

   local new_turn = false
   if new_turn then
   end
   local add_timestamps = true
   if add_timestamps then
      local minute = require("game.field").data.date.minute
      text = string.format("[%d] %s", minute, text)
   else
      self.current_width = 2
   end

   self.history:push({text = text, color = color})
   self:push_text(text, color)
   self.redraw = true
end

function UiMessageWindow:update()
end

return UiMessageWindow