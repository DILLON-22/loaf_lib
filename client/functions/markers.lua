local markers, amountMarkers = {}, 0
local nearbyMarkers, insideMarkers = {}, {}

-- ADD MARKER
function functions.AddMarker(markerData, onEnter, onExit, onPress)    
    local markerId = functions.GenerateUniqueKey(markers)
    
    markerData.id = markerId

    markerData.type = markerData.type or 1
    markerData.dir = markerData.dir or vector3(0.0, 0.0, 0.0)
    markerData.rot = markerData.rot or vector3(0.0, 0.0, 0.0)
    markerData.scale = markerData.scale or vector3(1.0, 1.0, 0.5)
    markerData.r = markerData.r or 125
    markerData.g = markerData.g or 75
    markerData.b = markerData.b or 195
    markerData.alpha = markerData.alpha or 100

    markers[markerId] = {
        data = markerData,
        callbacks = {
            onEnter = onEnter, -- this callback will be triggered when you enter the marker
            onPress = onPress, -- this callback will be triggered when you press E (or markerData.Control)
            onExit = onExit -- this callback will be triggered when you exit the marker
        },
        creator = GetInvokingResource()
    }
    amountMarkers = amountMarkers + 1
    return markerId
end

-- REMOVE MARKER
function functions.RemoveMarker(markerId)
    if markers[markerId] then 
        if insideMarkers[markerId] and markers[markerId].data.text then
            functions.HideHelpText()
        end
        markers[markerId] = nil
        amountMarkers -= 1
        return true
    end
    return false
end

-- GET MARKER
function functions.GetMarker(markerId)
    return markers[markerId]
end

-- GET MARKERS
function functions.GetMarkers()
    return markers
end

-- HANDLE MARKERS
CreateThread(function()
    function functions.IsInMarker(markerId)
        return insideMarkers[markerId] == true
    end

    -- THREAD THAT HANDLES NEARBY MARKERS
    CreateThread(function()
        while true do
            Wait(2500)
            local startTime = GetGameTimer()

            local newNearby = {}
            local selfCoords = GetEntityCoords(PlayerPedId())
            for markerId, markerData in pairs(markers) do
                if markerData and #(selfCoords - markerData.data.coords) <= 150.0 then
                    table.insert(newNearby, markerId)
                end
                Wait(5) -- wait increases performance quite a bit, no wait = a lot of cpu usage BUT really fast
            end

            -- print(string.format("Looping through all %i markers took %.5fs\nYou are nearby %i markers.", amountMarkers, (GetGameTimer() - startTime) / 1000, #newNearby))

            nearbyMarkers = newNearby
            collectgarbage()
        end
    end)

    -- THREAD THAT HANDLES THE DRAWING OF MARKERS
    while true do
        Wait(2500)
        local checkInside = 0
        while #nearbyMarkers > 0 do
            Wait(0)
            local selfCoords = GetEntityCoords(PlayerPedId())
            for _, markerId in pairs(nearbyMarkers) do
                if markers[markerId] then
                    local markerData = markers[markerId].data
                    DrawMarker(
                        markerData.type, 
                        markerData.coords, 
                        markerData.dir, 
                        markerData.rot, 
                        markerData.scale, 
                        markerData.r, 
                        markerData.g, 
                        markerData.b, 
                        markerData.alpha, 
                        false, false, 2, nil, nil, false
                    )
                    
                    if checkInside <= GetGameTimer() then
                        local bottomLeft = vector3(markerData.coords.x - markerData.scale.x/2, markerData.coords.y - markerData.scale.y/2, markerData.coords.z - markerData.scale.z)
                        local topRight = vector3(markerData.coords.x + markerData.scale.x/2, markerData.coords.y + markerData.scale.y/2, markerData.coords.z + 1.5)
                        local insideMarker = IsEntityInArea(PlayerPedId(), bottomLeft, topRight, false, true, 0)

                        if insideMarker then
                            if not insideMarkers[markerId] then
                                insideMarkers[markerId] = true
                                if markerData.text then
                                    functions.DrawHelpText(markerData.text, markerData.coords + vector3(0.0, 0.0, 1.0), markerData.key)
                                end
                                if markers[markerId].callbacks.onEnter then
                                    markers[markerId].callbacks.onEnter(markerData.callbackData.enter, markerData)
                                end
                            end
                        elseif insideMarkers[markerId] then
                            insideMarkers[markerId] = false
                            if markerData.text then
                                functions.HideHelpText()
                            end
                            if markers[markerId].callbacks.onExit then
                                markers[markerId].callbacks.onExit(markerData.callbackData.exit, markerData)
                            end
                        end
                    end
                end
            end

            if checkInside <= GetGameTimer() then
                checkInside = GetGameTimer() + 250
            end
        end
        insideMarkers = {}
    end
end)

RegisterNetEvent("loaf_lib:releasedKey", function(keyName)
    for markerId, inside in pairs(insideMarkers) do
        if not inside then 
            goto continue
        end

        local markerData = markers[markerId]
        if markerData?.data?.key ~= keyName then
            goto continue
        end

        if markerData and markerData.callbacks.onPress then 
            TriggerEvent("loaf_lib:usedMarker", markerId)
        end

        ::continue::
    end
end)

RegisterNetEvent("loaf_lib:usedMarker", function(markerId)
    local markerData = markers[markerId]
    markerData.callbacks.onPress(markerData.data.callbackData.press, markerData.data)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        local markersRemoved = 0
        for markerId, markerData in pairs(markers) do
            if markerData.creator == resourceName then
                functions.RemoveMarker(markerId)
                markersRemoved += 1
            end
        end
        if markersRemoved > 0 then
            print(string.format("Removed %i marker%s due to resource %s stopping.", markersRemoved, markersRemoved > 1 and "s" or "", resourceName))
        end
    end
end)