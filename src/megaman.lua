-- megaman
-- PPUMASK = 0x2001
-- INPUTS = 0x0014
-- INPUTS_TAPPED = 0x0018
-- BULLET_ON_SCREEN = 0x0060
-- HEALTH = 0x006A

-- megaman 2
PPUMASK = 0x2001
INPUTS = 0x0023
INPUTS_TAPPED = 0x0027
BULLET_ON_SCREEN = 0x003D
HEALTH = 0x06C0
MEGAMAN_X = 0x0460
MEGAMAN_Y = 0x04A0


mvslib = require("mvslib")


function on_ppumask_write(address, size, value)
    memory.registerwrite(PPUMASK, 1, nil)
    memory.writebyte(PPUMASK, OR(value, 0x41))
    memory.registerwrite(PPUMASK, on_ppumask_write)
end

function on_draw()
    screenshot = gui.gdscreenshot(false)
    local mirrored = mvslib.mirror_image(screenshot)
    gui.gdoverlay(mirrored)
    -- chunkwidth = 1
    -- chunkheight = 8
    -- for i=0,256/chunkheight do
    --     x, y = chunkwidth*i, chunkheight*i
    --     gui.gdoverlay(x, y, screenshot, 0, y, 256-x, chunkheight, 1)
    --     gui.gdoverlay(0, y, screenshot, 256-x, y, x, chunkheight, 1)
    -- end
end

life = 0
minlife = 0
bounce = 3
maxlife = 28
broken_sprite_no = 0
function sprite_boxes()
    memory.writebyte(HEALTH, minlife + life)
    life = life + 0.5*bounce
    if life >= maxlife - minlife or life <= 0 then
        bounce = -bounce
    end
    for i=0,63 do
        sprite_attrs = memory.readbyte(0x0200 + i*4 + 2)
        memory.writebyte(0x0200 + i*4 + 2, XOR(sprite_attrs, 0x40))
    end

    broken_sprite_no = (broken_sprite_no + 0.1) % 64
    -- for i=0,63 do
    --     y = memory.readbyte(0x0200 + i*4)
    --     x = memory.readbyte(0x0200 + i*4 + 3)
    --     gui.setpixel(x, y, "red")
    -- end
end

function on_tap()
    memory.registerwrite(INPUTS_TAPPED, 1, nil)
    buttons = joypad.read(1)
    taps = memory.readbyte(INPUTS_TAPPED)
    if taps ~= 0 then
        emu.print("taps ", taps)
    end

    taps = AND(taps, 0xFC)

    if buttons["A"] then
        taps = OR(taps, 0x1)
    end

    if buttons["B"] then
        taps = OR(taps, 0x2)
    end
    memory.writebyte(INPUTS_TAPPED, taps)
    memory.registerwrite(INPUTS_TAPPED, 1, on_tap)
end

function on_input()
    memory.register(INPUTS, 1, nil)
    buttons = joypad.read(1)
    inputs = memory.readbyte(INPUTS)

    inputs = AND(inputs, 0xFC, 0x3F)

    if buttons["A"] then
        inputs = OR(inputs, 0x2)
    end

    if buttons["B"] then
        inputs = OR(inputs, 0x1)
    end

    if buttons["left"] then
        inputs = OR(inputs, 0x40)
    end

    if buttons["right"] then
        inputs = OR(inputs, 0x80)
    end

    memory.writebyte(INPUTS, inputs)
    memory.register(INPUTS, 1, on_input)
end

function cursor()
    inputs = input.get()
    gui.box(inputs.xmouse - 5, inputs.ymouse - 5, inputs.xmouse + 5, inputs.ymouse + 5)
end

last_save = 0
save = savestate.object()
function periodic_save()
    now = os.time()
    if now - last_save > 5 then
        save2 = save
        save = savestate.object()
        savestate.save(save)
        savestate.load(save2)
        last_save = now
    end
end

bullet_speed = 4
bullet_x = 128
bullet_y = 128
bullet_w = 2
bullet_h = 2
bullet_shown = false
function on_shoot(address, size, value)
    if value == 0 then
        return
    end
    if not bullet_shown then
        bullet_x = memory.readbyte(MEGAMAN_X) + 16
        bullet_y = memory.readbyte(MEGAMAN_Y)
    end
    bullet_shown = true
end

function draw_bullet()
    if not bullet_shown then
        return
    end
    gui.box(bullet_x - bullet_w, bullet_y - bullet_h, bullet_x + bullet_w, bullet_y + bullet_h)
    bullet_x = bullet_x + bullet_speed
    if bullet_x > 260 then
        bullet_shown = false
    end
end

function on_move(address, size, value)
    emu.print(value)
end

emu.speedmode("normal")
-- memory.registerwrite(PPUMASK, 1, on_ppumask_write)
memory.register(INPUTS, 1, on_input)
memory.registerwrite(BULLET_ON_SCREEN, 1, on_shoot)
-- memory.registerwrite(INPUTS_TAPPED, 1, on_tap)
gui.register(on_draw)
while true do
    sprite_boxes()
    cursor()
    -- periodic_save()
    draw_bullet()
    emu.frameadvance()
end