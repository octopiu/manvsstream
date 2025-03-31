
IrcChat = {}
TWITCH_IRC_HOST = "irc.chat.twitch.tv"
TWITCH_IRC_PORT = 6667

function IrcChat:new(o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  self.socket = nil
  emu.print("ok?")
  return o
end

function IrcChat:ReceiveAll()
    if self.socket == nil then
        return
    end
    while true do
        local s, status = self.socket:receive(1024)
        emu.print(s)
        if string.len(s) == 0 then
            break
        end
    end
end

function IrcChat:Connect(channel)
    socket = require("socket")
    self.channel = channel
    self.socket = socket.connect(TWITCH_IRC_HOST, TWITCH_IRC_PORT)
    emu.print("ok?")
    -- self.socket:settimeout(100)
    self.socket:send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands\r\n")
    -- self:ReceiveAll()
    self.socket:send("NICK justinfan666\r\n")
    -- self:ReceiveAll()
    self.socket:send(string.format("JOIN #%s\r\n", channel))
    -- self:ReceiveAll()
end

chat = IrcChat:new()
chat:Connect("piuk")
-- while true do
--     chat:ReceiveAll()
-- end