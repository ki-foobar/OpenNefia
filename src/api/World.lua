--- @module World

local Event = require("api.Event")
local save = require("internal.global.save")

local World = {}

local event_types = {
   second = 5,
   minute = 4,
   hour = 3,
   day = 2,
   month = 1,
   year = 0,
   none = -1,
}

--- Passes time in seconds.
---
--- @tparam int seconds
--- @tparam[opt] string events Which events to enable. Setting it will
---   enable events for it and all larger time intervals ("month"
---   enables events for month and year). Can be one of the following:
---  - second: `base.on_second_passed`
---  - minute: `base.on_minute_passed`
---  - hour: `base.on_hour_passed`
---  - month: `base.on_month_passed`
---  - year: `base.on_year_passed`
---  - none
function World.pass_time_in_seconds(seconds, events)
   events = event_types[events or "second"] or event_types.second
   local date = save.base.date

   if events >= 5 then
      Event.trigger("base.on_second_passed", {seconds=seconds})
   end

   date.second = date.second + seconds
   if date.second >= 60 then
      save.base.play_turns = save.base.play_turns + 1

      local minutes_passed = math.floor(date.second / 60)

      date.minute = date.minute + minutes_passed
      date.second = date.second % 60

      if events >= 4 then
         Event.trigger("base.on_minute_passed", {minutes=minutes_passed})
      end

      if date.minute >= 60 then
         local hours_passed = math.floor(date.minute / 60)

         date.hour = date.hour + hours_passed
         date.minute = date.minute % 60

         if events >= 3 then
            Event.trigger("base.on_hour_passed", {hours=hours_passed})
         end

         if date.hour >= 24 then
            -- events before

            local days_passed = math.floor(date.hour / 24)
            save.base.play_days = save.base.play_days + days_passed
            date.day = date.day + days_passed
            date.hour = date.hour % 24

            if events >= 2 then
               Event.trigger("base.on_day_passed", {days=days_passed})
            end

            if date.day >= 31 then
               local months_passed = math.floor(date.day / 31)
               date.month = date.month + months_passed
               date.day = date.day % 31

               if events >= 1 then
                  Event.trigger("base.on_month_passed", {months=months_passed})
               end

               if date.month >= 13 then
                  local years_passed = math.floor(date.month / 13)
                  date.year = date.year + years_passed
                  date.month = date.month % 13

                  if events >= 0 then
                     Event.trigger("base.on_year_passed", {years=years_passed})
                  end
               end
            end

            -- events after
         end
      end
   end
end

--- Returns the current date.
---
--- @treturn DateTime
function World.date()
   return save.base.date
end

--- Returns the current date in hours. Used in various places for time
--- tracking purposes.
---
--- @treturn int
function World.date_hours()
   return save.base.date:hours()
end

return World
