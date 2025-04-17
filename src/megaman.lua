mvslib = require("mvslib")

SCREEN_WIDTH = 256
SCREEN_HEIGHT = 240
DIR_RIGHT = 1
DIR_LEFT = -1
MAX_BULLETS = 16
MAX_LIFE = 28
LIFE_BOUNCE = 1.5
MEGAMAN_WIDTH = 16

PPUMASK = 0x2001

rockman = {
    INPUTS=0x0014,
    INPUTS_TAPPED=0x0018,
    BULLET_ON_SCREEN=0x0060,
    HEALTH=0x006A,
    MEGAMAN_X=0x0480,
    MEGAMAN_Y=0x0600,
    MEGAMAN_FACING=0x0097
}

rockman2 = {
    INPUTS=0x0023,
    INPUTS_TAPPED=0x0027,
    BULLET_ON_SCREEN=0x003D,
    HEALTH=0x06C0,
    MEGAMAN_X=0x0460,
    MEGAMAN_Y=0x04A0
}

bullet = {}
function bullet:new(o)
    o = o or {}
    setmetatable(o, self)
    self.base_speed = 4
    self.speed = 0
    self.x, self.y = 0, 0
    self.w, self.h = 2, 2
    self.shown = false
    self.__index = self
    return o
end

function bullet:shoot(x, y, dir)
    if self.shown then
        return
    end
    self.shown = true
    self.x, self.y = x, y
    self.speed = self.base_speed * dir
end

function bullet:draw()
    if not self.shown then
        return
    end
    gui.box(self.x - self.w, self.y - self.h, self.x + self.w, self.y + self.h, 'black', 'black')
    self.x = self.x + self.speed
    if self.x > SCREEN_WIDTH+4 or self.x < -4 then
        self.shown = false
    end
end

bouncer = {}
function bouncer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.max = 0
    self.bounce = 0
    self.min = 0
    self.current = 0
    return o
end

function bouncer:init(min, max, bounce)
    self.min = min
    self.max = max
    self.bounce = bounce
end

function bouncer:step()
    self.current = self.current + self.bounce
    if self.current >= self.max or self.current <= self.min then
        self.bounce = -self.bounce
    end
end


cursor = {}
function cursor:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.width, self.height = 5, 5
    self.color = "black"
    self.shown = false
    return o
end

function cursor:draw()
    if not self.shown then
        return
    end
    inputs = input.get()
    gui.box(inputs.xmouse - self.width, inputs.ymouse - self.height, inputs.xmouse + self.width, inputs.ymouse + self.height)
end


mvs = {}
function mvs:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.flags = {
        gameboy=false,
        mirrored=false,
        abrevert=false,
        skewed=false,
        decoys=false,
        life_bounce=false,
        ducks=false,
        life_mash=false
    }
    self.bullets = {}
    self.current_bullet = 1
    self.bullet_dt = os.clock()
    self.life_bouncer = bouncer:new()
    self.vars = rockman
    self.cursor = cursor:new()
    self.mash_pressed = false
    self.health = 0
    for i=1,MAX_BULLETS do
        table.insert(self.bullets, bullet:new())
    end
    return o
end

function mvs:on_ppumask_write(address, size, value)
    memory.registerwrite(address, 1, nil)
    if self.flags["gameboy"] then
        memory.writebyte(address, OR(value, 0x41))
    end
    memory.registerwrite(address, function(address, size, value)
        self:on_ppumask_write(address, size, value)
    end)
end

function mvs:step()
    if self.flags["life_bounce"] then
        self.life_bouncer:step()
    end
    inputs = joypad.read(1)
    if self.flags['life_mash'] then
        health = memory.readbyte(self.vars['HEALTH'])
        if inputs['A'] then
            if not self.mash_pressed then
                self.health = self.health + 3
                self.mash_pressed = true
            end
        else
            self.mash_pressed = false
        end
        if health >= 1 then
            self.health = self.health - 0.4
        end
        memory.writebyte(self.vars['HEALTH'], self.health)
    end
    if self.flags['decoys'] then
        now = os.clock()
        emu.message(now)
        if now - self.bullet_dt >= 0.05 then
            self:shoot()
            self.bullet_dt = now
        end
    end
end

function mvs:draw()
    if self.flags["ducks"] then
        self.cursor:draw()
    end
    if self.flags['decoys'] then
        for i=1,MAX_BULLETS do
            self.bullets[i]:draw()
        end
    end
    if self.flags['mirrored'] then
        shot = gui.gdscreenshot(false)
        mirrored_shot = mvslib.mirror_image(shot)
        gui.drawimage(mirrored_shot)
    end
end

function mvs:on_tap(address, size, value)
    if value == 0 then
        return
    end
    memory.registerread(address, 1, nil)
    buttons = joypad.read(1)
    taps = value

    if self.flags['abrevert'] then
        taps = AND(taps, 0xFC)
    
        if buttons["A"] then
            taps = OR(taps, 0x2)
        end
    
        if buttons["B"] then
            taps = OR(taps, 0x1)
        end
    
        memory.writebyte(address, taps)
    end
    memory.registerread(address, 1, function(address, size, value) mvs:on_tap(address, size, value) end)
end

function mvs:on_input(address, size, value)
    memory.registerread(address, 1, nil)
    buttons = joypad.read(1)
    inputs = value

    if self.flags['abrevert'] then
        inputs = AND(inputs, 0xFC)

        if buttons["A"] then
            inputs = OR(inputs, 0x2)
        end
    
        if buttons["B"] then
            inputs = OR(inputs, 0x1)
        end
    end

    if self.flags['mirrored'] then
        inputs = AND(inputs, 0x3F)

        if buttons["left"] then
            inputs = OR(inputs, 0x80)
        end

        if buttons["right"] then
            inputs = OR(inputs, 0x40)
        end
    end

    if self.flags['mirrored'] or self.flags['abrevert'] then
        memory.writebyte(address, inputs)
    end

    memory.registerread(address, 1, function(address, size, value) mvs:on_input(address, size, value) end)
end

function mvs:set_flag(flag, onoff)
    self.flags[flag] = onoff
    if flag == "life_bounce" then
        if onoff then
            self.bouncer:init(0, MAX_LIFE, LIFE_BOUNCE)
        end
    elseif flag == "gameboy" then
        if onoff then
            memory.registerwrite(PPUMASK, 1, function(address, size, value) self:on_ppumask_write(address, size, value) end)
        else
            memory.registerwrite(PPUMASK, 1, nil)
        end
    -- elseif flag == "decoys" then
        -- if onoff then
        --     memory.registerwrite(self.vars['BULLET_ON_SCREEN'], 1, function(address, size, value) self:on_shoot(address, size, value) end)
        -- else
        --     memory.registerwrite(self.vars['BULLET_ON_SCREEN'], 1, nil)
        -- end
    elseif flag == "abrevert" or flag == "mirrored" then
        if onoff then
            memory.registerread(self.vars['INPUTS'], 1, function(address, size, value) self:on_input(address, size, value) end)
            memory.registerread(self.vars['INPUTS_TAPPED'], 1, function(address, size, value) self:on_tap(address, size, value) end)
        end
    elseif flag == 'ducks' then
        self.cursor.shown = true
    end
end

function mvs:shoot()
    x, y = memory.readbyte(self.vars['MEGAMAN_X']), memory.readbyte(self.vars['MEGAMAN_Y'])
    if memory.readbyte(self.vars['MEGAMAN_FACING']) == 0 then
        dir = -1
    else
        dir = 1
    end
    x = x + dir * MEGAMAN_WIDTH
    self.current_bullet = (self.current_bullet + 1) % MAX_BULLETS + 1
    self.bullets[self.current_bullet]:shoot(x, y, dir)
end

function mvs:on_shoot(address, size, value)
    if value == 0 then
        return
    end
    memory.registerwrite(address, size, nil)
    x, y = memory.readbyte(self.vars['MEGAMAN_X']), memory.readbyte(self.vars['MEGAMAN_Y'])
    if memory.readbyte(self.vars['MEGAMAN_FACING']) == 0 then
        dir = -1
    else
        dir = 1
    end
    x = x + dir * MEGAMAN_WIDTH
    for i=1,MAX_BULLETS do
        self.bullets[i]:shoot(x, y+2*i, dir)
    end
    memory.registerwrite(address, size, function(address, size, value) self:on_shoot(address, size, value) end)
end

return mvs