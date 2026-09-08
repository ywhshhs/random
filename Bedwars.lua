-- BW: AlSploit bootstrap with compatibility patches.
-- Why it errored through loadstring:
--  1. Line 13 uses Luau type annotations (String: string) -> most executors'
--     loadstring compiles strict and dies on ':'. Stripped below.
--  2. The stray `if false` dead block at the top is removed for cleanliness.
--  3. On mobile executors getexecutorname()/http_request may not exist ->
--     safe shims so the executor check can't nil-call.

getexecutorname = getexecutorname or function() return "Unknown" end
if not (http_request or request or httprequest) then
    local function dummyHttp(_)
        return { Success = false, Body = "{}" }
    end
    http_request = dummyHttp
end

local src = game:HttpGet("https://raw.githubusercontent.com/ywhshhs/sss/main/alsploitLEEEEEAK.lua")

-- patch 1: drop the dead `if false` block at the top
src = src:gsub("^if false%s+then%s+local _unused = 0%s+end%s*", "", 1)
-- patch 2: strip the only type-annotated signature in the file
src = src:gsub("xorEncode%(String: string, key: string%)", "xorEncode(String, key)")

assert(not src:find("String: string", 1, true), "[BW] annotation strip failed")

local fn, err = loadstring(src)
if not fn then
    error("[BW] AlSploit failed to compile: " .. tostring(err))
end
print("[BW] AlSploit compiled, running...")
return fn()
