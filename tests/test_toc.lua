-- Manifest, namespace and package identity (criterion 13).
local H = dofile("tests/harness/wow.lua")
local files, fields = H.ReadToc("ForeverOneButton/ForeverOneButton.toc")
H.Equal(fields.Interface, "16001", "Forever interface (verified via GetBuildInfo on 1.60.1.70374)")
H.Equal(fields.Title, "Forever One Button", "title")
H.Equal(fields.SavedVariables, "ForeverOneButtonDB, ForeverOneButtonLog", "dedicated SavedVariables (settings, optional diagnostic log)")
H.Equal(fields.SavedVariablesPerCharacter, "ForeverOneButtonCharDB", "per-character cells")
H.Equal(fields.OptionalDeps, nil, "no optional dependency: the engine is built in")
H.Equal(fields.Dependencies, nil, "no hard dependency")
H.Equal(fields.RequiredDeps, nil, "no hard dependency")
H.Check(fields.Version:match("^%d+%.%d+%.%d+$") or fields.Version:match("^%d+%.%d+%.%d+%-alpha%.%d+$")
    or fields.Version:match("^%d+%.%d+%.%d+%-beta%.%d+$"), "semantic version (optional -alpha.N / -beta.N)")

local ns = H.Boot(nil)
H.Equal(ns.VERSION, fields.Version, "runtime version matches TOC")
H.Equal(ns.NAME, "ForeverOneButton", "technical identifier")
H.Equal(ns.TITLE, fields.Title, "runtime title matches TOC")

-- Every listed file exists; every shipped Lua file is listed.
local listed = {}
for _, file in ipairs(files) do
    listed[file] = true
    H.Check(io.open("ForeverOneButton/" .. file, "rb") ~= nil, "listed file exists: " .. file)
end
local finder = package.config:sub(1, 1) == "\\" and 'dir /b /s /a-d ForeverOneButton | findstr /e .lua' or 'find ForeverOneButton -name "*.lua"'
local count = 0
for path in io.popen(finder):lines() do
    path = path:gsub("\\", "/"):match("ForeverOneButton/(.*)$")
    H.Check(listed[path], "unlisted Lua file shipped: " .. tostring(path))
    count = count + 1
end
H.Equal(count, #files, "no orphan Lua files")

-- Globals the addon creates: SavedVariables, slash command and named frames.
local allowed = {ForeverOneButtonDB = true, ForeverOneButtonCharDB = true, ForeverOneButtonLog = true, SLASH_FOREVERONEBUTTON1 = true, SLASH_FOREVERONEBUTTON2 = true}
for name in pairs(_G) do
    if type(name) == "string" and name:find("^ForeverOneButton") and not allowed[name] then
        H.Check(type(_G[name]) == "table" and _G[name].type ~= nil, "unexpected global " .. name)
    end
end
H.Done("test_toc")
