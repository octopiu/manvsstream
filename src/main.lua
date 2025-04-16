
emu.speedmode("normal")

manvsstream = mvs:new()
gui.register(manvsstream:on_draw)
while true do
    manvsstream:step()
    emu.frameadvance()
end
