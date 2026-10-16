-- Runs HCOneButton's own pixel regression (tests/fixtures/hcob/diagnostic_pixel_edge.lua,
-- byte-identical to hc-one-button e973acb) unchanged against the frozen original
-- producer. This proves the fixture is the real producer, not a copy that drifted.
local realDofile = dofile
dofile = function(path)
    if path == "HCOneButton/UI/DiagnosticPixel.lua" then path = "tests/fixtures/hcob/DiagnosticPixel.lua" end
    return realDofile(path)
end
realDofile("tests/fixtures/hcob/diagnostic_pixel_edge.lua")
print("test_original_regression: PASS")
