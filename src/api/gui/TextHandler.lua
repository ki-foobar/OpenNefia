local IKeyInput = require("api.gui.IKeyInput")

local internal = require("internal")

local TextHandler = class.class("TextHandler", IKeyInput)

function TextHandler:init()
   self.bindings = {}
   self.forwards = nil
   self.chars = {}
   self.this_frame = {}
   self.finished = false
   self.canceled = false
   self.halted = false
end

local function translate(char, text)
   if text then
      return char
   end

   return nil
end

function TextHandler:receive_key(char, pressed, text, is_repeat)
   if pressed and not is_repeat then self.halted = false end

   if not pressed then return end

   -- When IME input is sent, love first sends the keypress event of
   -- the user pressing "return" to confirm the IME submission, then
   -- it sends a text event with the text the IME entered in the same
   -- frame. Therefore, text shouldn't be submitted if a "return"
   -- keypress event is not the very last event received in this
   -- frame.
   if not text and char == "return" and pressed and not self.halted then
      self.finished = true
      return
   else
      -- If "return" was received earlier this frame, this prevents
      -- text submission.
      self.finished = false
   end

   if pressed and char == "escape" then
      self.canceled = true
   end

   if not text then
      self.this_frame[char] = true
      return
   end

   char = translate(char, text)
   if not char then return end

   if self.forwards then
      self.forwards:receive_key(char, pressed, text, is_repeat)
   else
      table.insert(self.chars, char)
   end
end

function TextHandler:bind_keys(bindings)
   for k, v in pairs(bindings) do
      self.bindings[k] = v
   end
end

function TextHandler:unbind_keys(bindings)
   for _, k in ipairs(bindings) do
      self.bindings[k] = nil
   end
end

function TextHandler:forward_to(handler)
   class.assert_is_an(IKeyInput, handler)
   self.forwards = handler
end

function TextHandler:focus()
   internal.input.set_key_repeat(true)
   internal.input.set_text_input(true)
   internal.input.set_key_handler(self)
end

function TextHandler:halt_input()
   self.halted = true
end

function TextHandler:update_repeats()
end

function TextHandler:key_held_frames()
   return 0
end

function TextHandler:run_key_action(key)
   if self.bindings[key] then
      self.bindings[key]()
   elseif self.bindings["text_entered"] then
      self.bindings["text_entered"](key)
   end
end

function TextHandler:run_actions()
   local ran = {}
   for _, c in ipairs(self.chars) do
      self:run_key_action(c)
      ran[c] = true
   end

   for c, _ in pairs(self.this_frame) do
      if not ran[c] then
         if self.bindings[c] then
            self.bindings[c]()
         end
      end
   end

   if self.finished and self.bindings["text_submitted"] then
      self.bindings["text_submitted"]()
   end

   if self.canceled and self.bindings["text_canceled"] then
      self.bindings["text_canceled"]()
   end

   self.chars = {}
   self.this_frame = {}

   self.finished = false
   self.canceled = false
end

return TextHandler
