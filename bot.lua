local discordia = require('discordia')
local http = require('coro-http')
local api = require('fromage')
local timer = require('timer')
local utils = require('utils')

local dClient = discordia.Client({
    cacheAllMembers = true
})

local fClient = api()

local guild = nil
local id = 1051168
local updated = 1574635902000
local histLogs = {}
local members = {}


coroutine.wrap(function()
    
    print('Logging...')
    fClient.connect('Mouseclick1#0000', os.getenv('FORUM_PASSWORD'))
    guild = dClient:getGuild('522976111836004353')

    dClient:on('messageCreate', function(msg) 
        if msg.content:lower() == '> ping' then
            msg:reply('Pong!')
        end
    end)

    getMembers()
    loop()
    timer.setInterval(1000*60*5, loop)

end)()

function loop()
    changes, updated = fetchChanges(updated)
    updateRanks(changes)
end

function getMembers()
    print('Connecting to members...')
    local page = 1
    local p1 = fClient.getTribeMembers(id, page)
    print('Fetching members... (total pages:' .. p1._pages .. ')')
    while page <= p1._pages do
        print('Getting page ' .. page .. ' of ' ..p1._pages .. ' ...')
        for _, member in next, fClient.getTribeMembers(id, page) do
            if (type(member) == 'table') then
                members[member.name] = member.rank
            end
        end
        page = page + 1
    end
    print('Fetching finished!')
    updated = fClient.getTribeHistory(id)[1].timestamp
    print('Updated all members!')
end


function fetchChanges(till)
    local page = 1
    local h1 = fClient.getTribeHistory(id)
    local hist = {}
    local completed = false
    if h1[1].timestamp > updated then
        print('Detected new changes')
        while not completed do
            print('Fetching page ' .. page .. '...')
            for _, log in next, fClient.getTribeHistory(id, page) do
                if type(log) == 'table' then
                    if log.timestamp <= till then
                        print('Fetched new records')
                        completed = true
                        break    
                    end
                    table.insert(hist, log.log)
                end
            end
            page = page + 1
        end
    end
    return hist, h1[1].timestamp
end


function updateRanks(logs)
    print('Queueing members and ranks...')
    local toUpdate = {}
    for _, v in next, logs do
        if getRankUpdate(v) then   
            local n, r = getRankUpdate(v)
            print('Queued ' .. n .. '!')
            members[n] = r
            toUpdate[n] = r
        end
    end

    print('Updating ranks!')
    for k, v in pairs(guild.members) do
        for n, r in next, toUpdate do
            print('Updating ' .. n .. '...')
            if v.nickname  and not not n:find(v.nickname .. '#?%d*') then
                v:addRole('655289933463945246')
                print('Updated ' .. v.nickname .. '!')
            end
        end
    end
    print('Updating finished!')
end

function getRankUpdate(log)
    --return log:match('.* has changed the rank of (.+#%d+) to (.+)')
    --Detecting rank changes
    if log:match('.- has changed the rank of (.-#?%d*) to (.+).') then
        return log:match('.- has changed the rank of (.-#?%d*) to (.+).')
    --Detecting joinings
    elseif log:match('(.-#?%d*) has joined the tribe.') then
        return log:match('(.-#?%d*) has joined the tribe.'), 'Stooge'
    --Detecting leaves
    elseif log:match('(.-#?%d*) has left the tribe.') then
        return log:match('(.-#?%d*) has left the tribe'), 'Passer By'
    end    
end

dClient:run('Bot ' .. os.getenv('DISCORD'))