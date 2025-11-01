
local data = nil
local fh = io.open(".\\tools\\lcpp.lua", "r")
print(fh)
if(fh) then data = fh:read("a*"); fh:close() end
for i = 1, #data do
    local b = data:byte(i)
    if b < 32 or b > 126 then
      print(i, string.format("%02X", b))
    end
end