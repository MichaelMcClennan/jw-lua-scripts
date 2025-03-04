function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Nick Mazuk"
    finaleplugin.Version = "1.0.2"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Date = "June 12, 2020"
    finaleplugin.CategoryTags = "Expression"
    finaleplugin.AuthorURL = "https://nickmazuk.com"
    return "Move Expression Baseline Down", "Move Expression Baseline Down",
           "Moves the selected expression above baseline down one space"
end

local path = finale.FCString()
path:SetRunningLuaFolderPath()
package.path = package.path .. ";" .. path.LuaString .. "?.lua"
local measurement = require("library.measurement")

function expression_baseline_move_down()
    local region = finenv.Region()
    local systems = finale.FCStaffSystems()
    systems:LoadAll()

    local start_measure = region:GetStartMeasure()
    local end_measure = region:GetEndMeasure()
    local system = systems:FindMeasureNumber(start_measure)
    local lastSys = systems:FindMeasureNumber(end_measure)
    local system_number = system:GetItemNo()
    local lastSys_number = lastSys:GetItemNo()
    local start_slot = region:GetStartSlot()
    local end_slot = region:GetEndSlot()

    for i = system_number, lastSys_number, 1 do
        local baselines = finale.FCBaselines()
        baselines:LoadAllForSystem(finale.BASELINEMODE_EXPRESSIONABOVE, i)
        for j = start_slot, end_slot do
            bl = baselines:AssureSavedStaff(finale.BASELINEMODE_EXPRESSIONABOVE, i, region:CalcStaffNumber(j))
            bl.VerticalOffset = bl.VerticalOffset - measurement.convert_to_EVPUs("1s")
            bl:Save()
        end
    end
end

expression_baseline_move_down()
