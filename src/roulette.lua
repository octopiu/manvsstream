math.randomseed(os.time())

roulette = {}
function roulette:new(choices)
    o = {}
    setmetatable(o, self)
    self.choices = choices
    self.choice = nil
    self.shown = false
    self.counter = 0
    self.callback = nil
    self.__index = self
    return o
end

function roulette:launch()
    self.shown = true
    self.counter = math.random(10, 128)
end

function roulette:on_chosen(callback)
    self.callback = callback
end

function roulette:step()
    if self.counter <= 0 then
        return
    end
    self.counter = self.counter - 1
    self.choice = self.choices[math.random(table.getn(self.choices))]
    if self.counter == 0 and self.callback ~= nil then
        self.callback(self.choice)
        self.shown = false
    end
end

function roulette:draw()
    if self.choice ~= nil and self.shown then
        emu.message(self.choice)
        -- gui.text(16, 16, self.choice, 'white', 'black')
    end
end

return roulette