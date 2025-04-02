mvslib = require("mvslib")
socket = require("socket.core")

IrcChat = {}
TWITCH_IRC_HOST = "irc.chat.twitch.tv"
TWITCH_IRC_PORT = 6667

function IrcChat:new(o)
    o = o or {}   -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    self.socket = nil
    self.buffer = ""
    return o
end

function IrcChat:ReceiveAll()
    if self.socket == nil then
        return
    end
    while true do
        local recv, send, err = socket.select({self.socket}, {}, 0.001)
        if err ~= nil then
            break
        end
        local s, status = self.socket:receive()
        if s == nil then
            break
        end
        self.buffer = self.buffer..s
    end
end

function IrcChat:Connect(channel)
    self.channel = channel
    self.socket = socket.tcp()
    self.socket:connect(TWITCH_IRC_HOST, TWITCH_IRC_PORT)
    self.socket:send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands\r\n")
    self:ReceiveAll()
    self.socket:send("NICK justinfan666\r\n")
    self:ReceiveAll()
    self.socket:send(string.format("JOIN #%s\r\n", channel))
    self:ReceiveAll()
end

function IrcChat:PopMessage(channel)
    idx = self.buffer:find("\r\n")
    if idx == nil then
        return nil
    end
    message = mvslib.parse_irc_message(self.buffer:sub(1, idx-1))
    self.buffer = self.buffer:sub(idx+2, self.buffer:len())
    return message
end

irc_thread = coroutine.create(function()
    chat = IrcChat:new()
    chat:Connect("piuk")
    while true do
        chat:ReceiveAll()
        coroutine.yield(chat:PopMessage())
    end
end)

while true do
    local status, message = coroutine.resume(irc_thread)
    if message ~= "" and message ~= nil then
        emu.print(message)
    end
    emu.frameadvance()
end