-- Coste de llamadas a funciones "host" (simuladas) y de bucle de script.
local function host_add(a, b) return a + b end
local N = 5000000
local t0 = os.clock()
local acc = 0
for i = 1, N do acc = host_add(acc, i) end
local dt = os.clock() - t0
print(string.format("M2 LUA calls=%d sec=%.3f ns_per_call=%.1f", N, dt, dt / N * 1e9))

-- Límite de instrucciones (protección ante bucles infinitos)
local function run_limited(f, max_instr)
  local count = 0
  local co = coroutine.create(f)
  debug.sethook(co, function() count = count + 1000; if count > max_instr then error("INSTRUCTION_BUDGET_EXCEEDED") end end, "", 1000)
  return coroutine.resume(co)
end
local ok, err = run_limited(function() while true do end end, 1e7)
print("M2 LUA_RUNAWAY_STOPPED=", not ok, "msg=", tostring(err))

-- Límite de memoria: Lua estándar no lo impone; medimos el crecimiento sin límite nativo
collectgarbage("collect")
local before = collectgarbage("count")
local t = {}
for i = 1, 200000 do t[i] = {i} end
local after = collectgarbage("count")
print(string.format("M2 LUA_MEM_GROWTH_KB=%.0f (sin límite nativo: requiere allocator propio)", after - before))
