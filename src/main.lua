mvs = require('megaman')
roulette = require('roulette')
emu.speedmode("normal")

function check_input()
    inputs = input.read()
    if inputs['RightCtrl'] then
        r:launch()
    end
end

manvsstream = mvs:new()
-- manvsstream:set_flag('gameboy', true)
manvsstream:set_flag('decoys', true)
-- manvsstream:set_flag('mirrored', true)
-- manvsstream:set_flag('life_mash', true)
manvsstream:set_flag('ducks', true)

r = roulette:new({'gameboy', 'decoys', 'life_mash', 'life_bounce'})
r:on_chosen(function(choice)
    emu.message(choice)
    manvsstream:set_flag(choice, true)
end)

gui.register(function()
    r:draw()
    manvsstream:draw()
end)
while true do
    check_input()
    r:step()
    manvsstream:step()
    emu.frameadvance()
end
