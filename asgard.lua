--[[
Copyright (c) 2026, Kyle Jordan

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]--

-- Addon metadata
_addon.name     = 'asgard'
_addon.author   = 'Kyle Jordan'
_addon.version  = '0.0.1'
_addon.command  = 'asgard'
_addon.commands = {'asg',}

-- Libraries
require('tables')
require('strings')
require('logger')
config    = require('config')
packets   = require('packets')
resources = require('resources')

-- Default settings
defaults = {}
defaults.debug = false
defaults.player = {}
defaults.player.main = 'Main'
defaults.player.alt = 'Alt'
defaults.follow = {}
defaults.follow.attemptzone = true
defaults.timing = 1.2
defaults.wincontrol = {}
defaults.wincontrol.main = {}
defaults.wincontrol.main.enabled = false
defaults.wincontrol.main.x = 0
defaults.wincontrol.main.y = 0
defaults.wincontrol.alt = {}
defaults.wincontrol.alt.enabled = false
defaults.wincontrol.alt.x = 3840
defaults.wincontrol.alt.y = 0
defaults.xivhotbar = {}
defaults.xivhotbar.enabled = true
defaults.autologin = {}
defaults.autologin.enabled = false
defaults.autologin.delay = 5
settings = config.load(defaults)

-- Runtime state
asgard = {}
asgard.player = {}
asgard.follow = false
asgard.rattack = false

------------------------------------------------------------
-- Utilities
------------------------------------------------------------

-- Returns the target unchanged if it is a valid named target or numeric ID, or 'me' as a fallback for any unrecognized value.
function validate_target(target)
    if L{'all', 'me', 'main', 'alt'}:contains(target) then
        return target
    elseif type(target) == 'number' then
        return target
    else
        return 'me'
    end
end

-- Returns the player's follow_index if currently following, or nil if not.
function is_following()
    return windower.ffxi.get_player().follow_index
end

-- Loads a Windower addon by name after waiting for the local player's job data to become available.
-- Polls up to 30 times at settings.timing intervals, then warns if job data never arrives.
function delay_load(name)
    local attempts = 0
    while attempts < 30 do
        local p = windower.ffxi.get_player()
        if p and p.main_job_id and p.main_job_id > 0 then
            windower.send_command('lua load ' .. name)
            if settings.debug then log('delay_load: loaded ' .. name) end
            return
        end
        coroutine.sleep(settings.timing)
        attempts = attempts + 1
    end
    warning('[asgard] delay_load: timed out waiting for job data (' .. name .. ')')
end

------------------------------------------------------------
-- Commands
------------------------------------------------------------

-- Dispatches an addon command to its matching handler function.
function addon_command(cmd, ...)
    if settings.debug then log('Command dispatched: ' .. tostring(cmd)) end
    if cmd == 'command' or cmd == 'cmd' then
        command(...)
    elseif cmd == 'attack' or cmd == 'atk' then
        attack(...)
    elseif cmd == 'buffs' or cmd == 'buf' then
        buffs(...)
    elseif cmd == 'follow' or cmd == 'fol' then
        follow(...)
    elseif cmd == 'mount' or cmd == 'mnt' then
        mount(...)
    elseif cmd == 'debug' or cmd == 'dev' then
        debug()
    elseif cmd == 'eval' or cmd == 'evl' then
        eval(...)
    elseif cmd == 'rattack' or cmd == 'rat' then
        rattack(...)
    else
        ---@diagnostic disable: undefined-field
        windower.add_to_chat(0, ('%s (v%s)'):format(_addon.name:color(5), _addon.version))
        windower.add_to_chat(0, ('    %s - %s'):format(('command'):color(50), 'Sends a command to a target character'))
        windower.add_to_chat(0, ('    %s - %s'):format(('attack'):color(50), 'Engages or disengages from a combat target (on, off, toggle)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('buffs'):color(50), 'Adjusts status effects on a target (add, remove, toggle, cancel)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('follow'):color(50), 'Follows or stops following the main character (on, off, toggle)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('mount'):color(50), 'Mounts or dismounts by name (on, off, toggle)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('rattack'):color(50), 'Starts or stops an automatic ranged attack loop (on, off, toggle)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('debug'):color(50), 'Toggles debug mode on/off (default: false)'))
        windower.add_to_chat(0, ('    %s - %s'):format(('eval'):color(50), 'Evaluates a Lua expression in the context of this addon'))
        ---@diagnostic enable: undefined-field
    end
end

-- Routes a 'send' command to the specified target character.
function command(mode, target, ...)
    if mode == 'send' then
        local cmd = L{...}:concat(' '):lower()
        if settings.debug then log('Sending to [' .. tostring(target) .. ']: ' .. cmd) end
        if target == 'all' then
            windower.send_command('send @all ' .. cmd)
        elseif target == 'me' then
            local name = asgard.player.name or (windower.ffxi.get_player() or {}).name
            if name then
                windower.send_command('send ' .. name .. ' ' .. cmd)
            else
                warning('Cannot send to me: player name is unavailable.')
            end
        elseif target == 'main' then
            windower.send_command('send ' .. settings.player.main .. ' ' .. cmd)
        elseif target == 'alt' then
            windower.send_command('send ' .. settings.player.alt .. ' ' .. cmd)
        else
            warning('Command target is incorrect or missing.')
        end
    else
        warning('Command mode is missing or not supported.')
    end
end

------------------------------------------------------------
-- Actions
------------------------------------------------------------

-- Engages or disengages the player from a combat target via outgoing packets.
function attack(mode, target, ...)
    local function is_engaged()
        return windower.ffxi.get_player().status == 1 -- status 1 = engaged
    end
    local _mode = mode or 'off'
    if target or mode == 'off' then
        if (L{'on', 'toggle'}:contains(_mode)) and (not(is_engaged())) then
            local mob = windower.ffxi.get_mob_by_id(target) -- Gets the mob entity by id
            if not mob then
                if settings.debug then warning('Attack target not found or out of range.') end
                return
            end
            local engage = packets.new('outgoing', 0x1A, {
                ["Target"] = mob.id,
                ["Target Index"] = mob.index,
                ["Category"] = 0x02 -- engage
            })
            packets.inject(engage) -- Sends a packet that makes player engage the target
        elseif (L{'off', 'toggle'}:contains(_mode)) and (is_engaged()) then
            local disengage = packets.new('outgoing', 0x1A, {
                ["Target"] = asgard.player.id,
                ["Target Index"] = asgard.player.index,
                ["Category"] = 0x04 -- disengage
            })
            packets.inject(disengage) -- Sends a packet that makes player disengage
        elseif not L{'on', 'off', 'toggle'}:contains(_mode) then
            warning('Attack mode invalid [on/off/toggle]')
        end
        -- If mode is valid but the player is already in the desired state, do nothing.
    else
        warning('Attack target invalid')
    end
end

-- Adds, removes, toggles, or cancels status effects on the specified target.
function buffs(mode, target, buffs, power, duration, subId, subPower)
    -- Resolves a buff name or numeric string to its game ID, or nil if not found.
    local function resolve_id(buff)
        local id = tonumber(buff)
        if id then return resources.buffs[id] and id end
        for _, b in pairs(resources.buffs) do
            if windower.wc_match(buff:lower(), b.name:lower()) then return b.id end
        end
    end
    -- Parses a comma-delimited string or table of buff names/IDs into a list of resolved IDs.
    local function resolve_ids(input)
        local raw = type(input) == 'table' and input or {}
        if type(input) ~= 'table' then
            for match in string.gmatch(input, '%w+') do
                table.insert(raw, match)
            end
        end
        local ids = T{}
        for _, v in pairs(raw) do
            local id = resolve_id(v)
            if id then ids:append(id) end
        end
        return ids
    end
    local _target   = validate_target(target)
    local _ids      = resolve_ids(buffs)
    local _active   = L(windower.ffxi.get_player().buffs)
    local _power    = tonumber(power)    or 1
    local _duration = tonumber(duration) or 3600
    local _subId    = tonumber(subId)    or 0
    local _subPower = tonumber(subPower) or 0
    for _, id in pairs(_ids) do
        if     (mode == 'add')    or (mode == 'toggle' and not _active:contains(id)) then
            command('send', _target, 'input', '!addeffect', id, _power, _duration, _subId, _subPower)
        elseif (mode == 'remove') or (mode == 'toggle' and _active:contains(id)) then
            command('send', _target, 'input', '!deleffect', id)
        elseif mode == 'cancel' then
            windower.packets.inject_outgoing(0xF1, string.char(0xF1, 0x04, 0, 0, id%256, math.floor(id/256), 0, 0))
        else
            warning('Buffs mode invalid [toggle/add/remove/cancel]')
        end
        ---@diagnostic disable-next-line: undefined-field
        coroutine.sleep(settings.timing)
    end
end

-- Starts, stops, or configures auto-follow on the main player.
function follow(mode, ...)
    local args = L{...} -- Stores the arguments (other than mode) in a variable
    local _mode = mode or 'toggle'
    if (L{'on', 'toggle'}:contains(_mode)) and (not(asgard.follow) or not(is_following())) then
        local main = windower.ffxi.get_mob_by_name(settings.player.main)
        if main then
            asgard.follow = true
            windower.ffxi.follow(main.index)
            if settings.debug then log('Follow enabled on: ' .. settings.player.main) end
        else
            warning('Follow target not found: ' .. settings.player.main .. ' is not in range.')
        end
    elseif (L{'off', 'toggle'}:contains(_mode)) and (asgard.follow or is_following()) then
        asgard.follow = false
        windower.ffxi.follow()
        if settings.debug then log('Follow disabled.') end
    elseif mode == 'attemptzone' then
        if args[1] == 'on' or (not(args[1]) and not(settings.follow.attemptzone)) then
            settings.follow.attemptzone = true
        elseif args[1] == 'off' or (not(args[1]) and settings.follow.attemptzone) then
            settings.follow.attemptzone = false
        end
        settings:save()
    elseif not L{'on', 'off', 'toggle', 'attemptzone'}:contains(mode) then
        warning('Follow mode invalid [on/off/toggle/attemptzone]')
    end
    -- If mode is valid but the player is already in the desired state, do nothing.
end

-- Mounts or dismounts the player using the requested mount, or the best available fallback.
function mount(mode, target, name)
    local function is_mounted()
        local b = resources.buffs:with('english', 'Mounted')
        return b and L(windower.ffxi.get_player().buffs):contains(b.id)
    end
    local _mode = mode or 'toggle'
    local _target = validate_target(target)
    if (L{'on', 'toggle'}:contains(_mode)) and (not(is_mounted())) then
        local abilities = windower.ffxi.get_abilities()
        local _name = nil
        if abilities then
            -- Searches owned mounts for the first one matching pred.
            local function find_mount(pred)
                for _, id in ipairs(abilities.mounts) do
                    local m = resources.mounts[id]
                    if m and pred(m.name:lower()) then return m.name end
                end
            end
            -- Priority: requested name → chocobo → first available mount.
            _name = (name and find_mount(function(n) return n == name:lower() end))
                 or find_mount(function(n) return n == 'chocobo' end)
                 or find_mount(function() return true end)
        end
        if not _name then
            warning('No usable mount found.')
            return
        end
        command('send', _target, 'input', '/mount', _name)
    elseif (L{'off', 'toggle'}:contains(_mode)) and (is_mounted()) then
        command('send', _target, 'input', '/dismount')
    elseif not L{'on', 'off', 'toggle'}:contains(_mode) then
        warning('Mount mode invalid [on/off/toggle]')
    end
    -- If mode is valid but the player is already in the desired state, do nothing.
end

-- Toggles debug mode and saves the updated setting to disk.
function debug()
    settings.debug = not settings.debug
    log(('Debug %s.'):format(settings.debug and 'enabled' or 'disabled'))
    settings:save()
end

-- Starts or stops an automatic ranged attack loop that re-triggers /range while the player is engaged.
-- The loop checks engagement status before each shot so it pauses naturally when combat ends.
function rattack(mode)
    local _mode = mode or 'toggle'
    if L{'on', 'toggle'}:contains(_mode) and not asgard.rattack then
        asgard.rattack = true
        if settings.debug then log('Ranged attack loop started.') end
        while asgard.rattack do
            if windower.ffxi.get_player().status == 1 then
                windower.send_command('input /range')
            end
            coroutine.sleep(settings.timing)
        end
        if settings.debug then log('Ranged attack loop stopped.') end
    elseif L{'off', 'toggle'}:contains(_mode) and asgard.rattack then
        asgard.rattack = false
    elseif not L{'on', 'off', 'toggle'}:contains(_mode) then
        warning('Rattack mode invalid [on/off/toggle]')
    end
    -- If mode is valid but rattack is already in the desired state, do nothing.
end

-- Evaluates an arbitrary Lua expression in the addon's context. Errors are shown as warnings rather than crashing.
function eval(...)
    local code = L{...}:concat(' ')
    if settings.debug then log('eval: ' .. code) end
    local fn, err = loadstring(code)
    if not fn then
        warning('eval: ' .. tostring(err))
        return
    end
    local ok, run_err = pcall(fn)
    if not ok then warning('eval: ' .. tostring(run_err)) end
end

------------------------------------------------------------
-- Event Handlers
------------------------------------------------------------

-- Runs on addon load or player login. Automatically presses through login screens if autologin
-- is enabled, then initializes player state, repositions the window, and deferred-loads addons.
function loaded()
    -- Autologin: press through all login screens if not yet in game.
    -- Checks logged_in before each press so stray keypresses can't fire after login completes.
    if settings.autologin.enabled and not windower.ffxi.get_info().logged_in then
        for _ = 1, 4 do
            coroutine.sleep(settings.autologin.delay)
            if windower.ffxi.get_info().logged_in then break end
            windower.send_command('setkey enter down')
            coroutine.sleep(0.3)
            windower.send_command('setkey enter up')
        end
        return
    end
    local player = windower.ffxi.get_player()
    if player then
        asgard.player = player
        local role = player.name == settings.player.main and 'main' or 'alt'
        local wc = settings.wincontrol[role]
        if wc and wc.enabled then
            windower.send_command('wincontrol move ' .. wc.x .. ' ' .. wc.y)
            if settings.debug then log('Moved window to ' .. wc.x .. ', ' .. wc.y .. ' (role: ' .. role .. ')') end
        end
    end
    if settings.xivhotbar.enabled then
        delay_load('xivhotbar')
    end
end

-- Runs on addon unload or player logout. Stops follow and ranged attack loop if active.
function unloaded()
    if asgard.follow then
        windower.ffxi.follow() -- Stop following so the character doesn't keep running after the addon is removed.
        asgard.follow = false
    end
    asgard.rattack = false
end

-- Runs when the player's status changes. Broadcasts engage/disengage events over IPC if run by the main character.
function status_change(new_id, old_id)
    if not asgard.player.id then return end
    if settings.debug then log('Status change: ' .. tostring(old_id) .. ' -> ' .. tostring(new_id)) end
    if asgard.player.name == settings.player.main and new_id == 1 then -- When the main character engages a mob
        local mob = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t') -- Get the sub-target or target mob
        if mob then
            windower.send_ipc_message(settings.player.main .. ' engaged ' .. mob.id) -- Send an ipc message to others to notify the target being engaged
        end
    elseif asgard.player.name == settings.player.main and new_id == 0 then -- When the main character disengages (goes idle)
        windower.send_ipc_message(settings.player.main .. ' disengaged.') -- Send an ipc message to others that the main character disengaged
    end
end

-- Runs when the local player changes zones. Broadcasts the zone event over IPC if run by the main character,
-- or waits for the main to appear in range and re-enables follow if the alt is tracking.
function zone_change(new_id, old_id)
    if not asgard.player.id then return end
    if settings.debug then log('Zone change: ' .. tostring(old_id) .. ' -> ' .. tostring(new_id)) end
    if asgard.player.name == settings.player.main then
        windower.send_ipc_message(asgard.player.name .. ' zoned.')
    else
        if asgard.follow then
            local attempts = 0
            while not(windower.ffxi.get_mob_by_name(settings.player.main)) and attempts < 20 do
                ---@diagnostic disable-next-line: undefined-field
                coroutine.sleep(settings.timing)
                attempts = attempts + 1
            end
            if windower.ffxi.get_mob_by_name(settings.player.main) then
                follow('on')
            end
        end
    end
end

-- Runs when an IPC message is received from another addon instance.
-- Responds to engaged, disengaged, and zoned broadcasts from the main character.
function ipc_message(message)
    if settings.debug then log('IPC received: ' .. message) end
    local msg = message:split(' ')
    if (message == settings.player.main .. ' zoned.') and (settings.follow.attemptzone and is_following()) then
        windower.ffxi.run()
    elseif (msg[1] == settings.player.main) and (msg[2] == 'engaged') then
        attack('on', tonumber(msg[3])) -- Instructs player to attack target
    elseif (msg[1] == settings.player.main) and (msg[2] == 'disengaged.') then
        attack('off') -- Instructs player to disengage
    end
end

-- Runs when a party invite is received. Auto-accepts if the sender is the main character.
function party_invite(sender, sender_id)
    log('Party invite from: ' .. sender)
    if sender == settings.player.main then
        command('send', 'me', 'input', '/join')
    end
end

------------------------------------------------------------
-- Event Registration
------------------------------------------------------------

windower.register_event('addon command',    addon_command)
windower.register_event('login', 'load',    loaded)
windower.register_event('unload', 'logout', unloaded)
windower.register_event('status change',    status_change)
windower.register_event('zone change',      zone_change)
windower.register_event('ipc message',      ipc_message)
windower.register_event('party invite',     party_invite)