--- Implements the random generator from the HSP runtime. It's a
--- linear congruential generator.
-- @module RandomGenerator

local IRandomGenerator = require("api.IRandomGenerator")

local RandomGenerator = class.class("RandomGenerator", IRandomGenerator)
local socket = require("socket")

function RandomGenerator:init(seed)
   self:set_seed(seed)
end

function RandomGenerator:set_seed(seed)
   if seed == nil then
      -- In OpenHSP on Windows this uses GetTickCount, on Unix it uses
      -- time(0).
      --
      -- https://github.com/onitama/OpenHSP/blob/1d3d134a5d12017a413cafe527768883fb85c8a1/src/hsp3/hsp3int.cpp#L1033
      seed = socket.gettime()
   end

   self.seed = seed
end

function RandomGenerator:rnd(n)
   self.seed = (214013 * self.seed + 2531011) % 4294967296
   return bit.band(bit.rshift(self.seed, 16), 0x7FFF) % n
end

function RandomGenerator:rnd_float()
   self:rnd(0)
   return self.seed / 4294967296
end

return RandomGenerator
