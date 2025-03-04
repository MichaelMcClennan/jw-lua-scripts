function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Nick Mazuk"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0.1"
    finaleplugin.Date = "March 30, 2021"
    finaleplugin.CategoryTags = "Pitch"
    finaleplugin.AuthorURL = "https://nickmazuk.com"
    return "String Harmonics 4th - Sounding Pitch", "String Harmonics 4th - Sounding Pitch",
           "Takes a sounding pitch, then creates the artificial harmonic that would produce that pitch"
end

local path = finale.FCString()
path:SetRunningLuaFolderPath()
package.path = package.path .. ";" .. path.LuaString .. "?.lua"
--[[
$module Articulation
]]

local articulation = {}

--[[
$module Note Entry
]]
local note_entry = {}

-- This function may not have been used anywhere, though it has been tested and works.
-- If you use this function, remove this comment.
-- If you remove this function, be sure to check that it still isn't used.
--[[
% get_music_region(entry)

Returns an intance of `FCMusicRegion` that corresponds to the metric location of the input note entry.

@ entry (FCNoteEntry)
: (FCMusicRegion)
]]
function note_entry.get_music_region(entry)
    local exp_region = finale.FCMusicRegion()
    exp_region:SetCurrentSelection() -- called to match the selected IU list (e.g., if using Staff Sets)
    exp_region.StartStaff = entry.Staff
    exp_region.EndStaff = entry.Staff
    exp_region.StartMeasure = entry.Measure
    exp_region.EndMeasure = entry.Measure
    exp_region.StartMeasurePos = entry.MeasurePos
    exp_region.EndMeasurePos = entry.MeasurePos
    return exp_region
end

--entry_metrics can be omitted, in which case they are constructed and released here
--return entry_metrics, loaded_here
local use_or_get_passed_in_entry_metrics = function(entry, entry_metrics)
    if nil ~= entry_metrics then
        return entry_metrics, false
    end
    entry_metrics = finale.FCEntryMetrics()
    if entry_metrics:Load(entry) then
        return entry_metrics, true
    end
    return nil, false
end

-- This function may not have been used anywhere, though it has been tested and works.
-- If you use this function, remove this comment.
-- If you remove this function, be sure to check that it still isn't used.
--[[
% get_evpu_notehead_height(entry)

Returns the calculated height of the notehead rectangle.

@ entry (FCNoteEntry)

: (number) the EVPU height
]]
function note_entry.get_evpu_notehead_height(entry)
    local highest_note = entry:CalcHighestNote(nil)
    local lowest_note = entry:CalcLowestNote(nil)
    local evpu_height = (2 + highest_note:CalcStaffPosition() - lowest_note:CalcStaffPosition()) * 12 -- 12 evpu per staff step; add 2 staff steps to accommodate for notehead height at top and bottom
    return evpu_height
end

--[[
% get_top_note_position(entry, entry_metrics)

Returns the vertical page coordinate of the top of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_top_note_position(entry, entry_metrics)
    local retval = -math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if not entry:CalcStemUp() then
        retval = entry_metrics.TopPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling*evpu_height)/10000) + 0.5)
            retval = entry_metrics.BottomPosition + scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% get_bottom_note_position(entry, entry_metrics)

Returns the vertical page coordinate of the bottom of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_bottom_note_position(entry, entry_metrics)
    local retval = math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if entry:CalcStemUp() then
        retval = entry_metrics.BottomPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling*evpu_height)/10000) + 0.5)
            retval = entry_metrics.TopPosition - scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% calc_widths(entry)

Get the widest left-side notehead width and widest right-side notehead width.

@ entry (FCNoteEntry)
: (number, number) widest left-side notehead width and widest right-side notehead width
]]
function note_entry.calc_widths(entry)
    local left_width = 0
    local right_width = 0
    for note in each(entry) do
        local note_width = note:CalcNoteheadWidth()
        if note_width > 0 then
            if note:CalcRightsidePlacement() then
                if note_width > right_width then
                    right_width = note_width
                end
            else
                if note_width > left_width then
                    left_width = note_width
                end
            end
        end
    end
    return left_width, right_width
end

-- These functions return the offset for an expression handle.
-- Expression handles are vertical when they are left-aligned
-- with the primary notehead rectangle.

--[[
% calc_left_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Left of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_all_noteheads(entry)
    if entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return -left
end

--[[
% calc_left_of_primary_notehead(entry)

Calculates the handle offset for an expression with "Left of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_primary_notehead(entry)
    return 0
end

--[[
% calc_center_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Center of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    local width_centered = (left + right) / 2
    if not entry:CalcStemUp() then
        width_centered = width_centered - left
    end
    return width_centered
end

--[[
% calc_center_of_primary_notehead(entry)

Calculates the handle offset for an expression with "Center of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_primary_notehead(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left / 2
    end
    return right / 2
end

--[[
% calc_stem_offset(entry)

Calculates the offset of the stem from the left edge of the notehead rectangle. Eventually the PDK Framework may be able to provide this instead.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset of stem from the left edge of the notehead rectangle.
]]
function note_entry.calc_stem_offset(entry)
    if not entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return left
end

--[[
% calc_right_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Right of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_right_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left + right
    end
    return right
end

--[[
% calc_note_at_index(entry, note_index)

This function assumes `for note in each(note_entry)` always iterates in the same direction.
(Knowing how the Finale PDK works, it probably iterates from bottom to top note.)
Currently the PDK Framework does not seem to offer a better option.

@ entry (FCNoteEntry)
@ note_index (number) the zero-based index
]]
function note_entry.calc_note_at_index(entry, note_index)
    local x = 0
    for note in each(entry) do
        if x == note_index then
            return note
        end
        x = x + 1
    end
    return nil
end

--[[
% stem_sign(entry)

This is useful for many x,y positioning fields in Finale that mirror +/-
based on stem direction.

@ entry (FCNoteEntry)
: (number) 1 if upstem, -1 otherwise
]]
function note_entry.stem_sign(entry)
    if entry:CalcStemUp() then
        return 1
    end
    return -1
end

--[[
% duplicate_note(note)

@ note (FCNote)
: (FCNote | nil) reference to added FCNote or `nil` if not success
]]
function note_entry.duplicate_note(note)
    local new_note = note.Entry:AddNewNote()
    if nil ~= new_note then
        new_note.Displacement = note.Displacement
        new_note.RaiseLower = note.RaiseLower
        new_note.Tie = note.Tie
        new_note.TieBackwards = note.TieBackwards
    end
    return new_note
end

--[[
% delete_note(note)

Removes the specified FCNote from its associated FCNoteEntry.

@ note (FCNote)
: (boolean) true if success
]]
function note_entry.delete_note(note)
    local entry = note.Entry
    if nil == entry then
        return false
    end

    -- attempt to delete all associated entry-detail mods, but ignore any failures
    finale.FCAccidentalMod():EraseAt(note)
    finale.FCCrossStaffMod():EraseAt(note)
    finale.FCDotMod():EraseAt(note)
    finale.FCNoteheadMod():EraseAt(note)
    finale.FCPercussionNoteMod():EraseAt(note)
    finale.FCTablatureNoteMod():EraseAt(note)
    --finale.FCTieMod():EraseAt(note)  -- FCTieMod is not currently lua supported, but leave this here in case it ever is

    return entry:DeleteNote(note)
end

--[[
% calc_spans_number_of_octaves(entry)

Calculates the numer of octaves spanned by a chord (considering only staff positions, not accidentals).

@ entry (FCNoteEntry) the entry to calculate from
: (number) of octaves spanned
]]
function note_entry.calc_spans_number_of_octaves(entry)
    local top_note = entry:CalcHighestNote(nil)
    local bottom_note = entry:CalcLowestNote(nil)
    local displacement_diff = top_note.Displacement - bottom_note.Displacement
    local num_octaves = math.ceil(displacement_diff / 7)
    return num_octaves
end

--[[
% add_augmentation_dot(entry)

Adds an augentation dot to the entry. This works even if the entry already has one or more augmentation dots.

@ entry (FCNoteEntry) the entry to which to add the augmentation dot
]]
function note_entry.add_augmentation_dot(entry)
    entry.Duration = bit32.bor(entry.Duration, bit32.rshift(entry.Duration, 1))
end

--[[
% get_next_same_v(entry)

Returns the next entry in the same V1 or V2 as the input entry.
If the input entry is V2, only the current V2 launch is searched.
If the input entry is V1, only the current measure and layer is searched.

@ entry (FCNoteEntry) the entry to process
: (FCNoteEntry) the next entry or `nil` in none
]]
function note_entry.get_next_same_v(entry)
    local next_entry = entry:Next()
    if entry.Voice2 then
        if (nil ~= next_entry) and next_entry.Voice2 then
            return next_entry
        end
        return nil
    end
    if entry.Voice2Launch then
        while (nil ~= next_entry) and next_entry.Voice2 do
            next_entry = next_entry:Next()
        end
    end
    return next_entry
end




--[[
% delete_from_entry_by_char_num(entry, char_num)

Removes any articulation assignment that has the specified character as its above-character.

@ entry (FCNoteEntry)
@ char_num (number) UTF-32 code of character (which is the same as ASCII for ASCII characters)
]]
function articulation.delete_from_entry_by_char_num(entry, char_num)
    local artics = entry:CreateArticulations()
    for a in eachbackwards(artics) do
        local defs = a:CreateArticulationDef()
        if defs:GetAboveSymbolChar() == char_num then
            a:DeleteData()
        end
    end
end

--[[
% is_note_side(artic, curr_pos)

Uses `FCArticulation.CalcMetricPos` to determine if the input articulation is on the note-side.

@ artic (FCArticulation)
@ [curr_pos] (FCPoint) current position of articulation that will be calculated if not supplied
: (boolean) true if on note-side, otherwise false
]]
function articulation.is_note_side(artic, curr_pos)
    if nil == curr_pos then
        curr_pos = finale.FCPoint(0, 0)
        if not artic:CalcMetricPos(curr_pos) then
            return false
        end
    end
    local entry = artic:GetNoteEntry()
    local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
    if nil == cell_metrics then
        return false
    end
    if entry:CalcStemUp() then
        local bot_pos = note_entry.get_bottom_note_position(entry)
        bot_pos = math.floor(((10000*bot_pos)/cell_metrics.StaffScaling) + 0.5)
        return curr_pos.Y <= bot_pos
    else
        local top_pos = note_entry.get_top_note_position(entry)
        top_pos = math.floor(((10000*top_pos)/cell_metrics.StaffScaling) + 0.5)
        return curr_pos.Y >= top_pos
    end
    return false
end



--[[
$module Transposition

A collection of helpful JW Lua transposition scripts
]] -- 
-- Structure
-- 1. Helper functions
-- 2. Diatonic Transposition
-- 3. Enharmonic Transposition
-- 3. Chromatic Transposition
-- 
local transposition = {}

--  Author: Robert Patterson
--  Date: March 5, 2021

--[[
$module Configuration

This library implements a UTF-8 text file scheme for configuration as follows:

- Comments start with `--`
- Leading, trailing, and extra whitespace is ignored
- Each parameter is named and delimited as follows:
`<parameter-name> = <parameter-value>`

Parameter values may be:

- Strings delimited with either single- or double-quotes
- Tables delimited with `{}` that may contain strings, booleans, or numbers
- Booleans (`true` or `false`)
- Numbers

Currently the following are not supported:

- Tables embedded within tables
- Tables containing strings that contain commas

A sample configuration file might be:

```lua
-- Configuration File for "Hairpin and Dynamic Adjustments" script
--
left_dynamic_cushion 		= 12		--evpus
right_dynamic_cushion		= -6		--evpus
```
]]

local configuration = {}

local script_settings_dir = "script_settings" -- the parent of this directory is the running lua path
local comment_marker = "--"
local parameter_delimiter = "="
local path_delimiter = "/"

local file_exists = function(file_path)
    local f = io.open(file_path,"r")
    if nil ~= f then
        io.close(f)
        return true
    end
    return false
end

local strip_leading_trailing_whitespace = function (str)
    return str:match("^%s*(.-)%s*$") -- lua pattern magic taken from the Internet
end

local parse_parameter -- forward function declaration

local parse_table = function(val_string)
    local ret_table = {}
    for element in val_string:gmatch('[^,%s]+') do  -- lua pattern magic taken from the Internet
        local parsed_element = parse_parameter(element)
        table.insert(ret_table, parsed_element)
    end
    return ret_table
end

parse_parameter = function(val_string)
    if '"' == val_string:sub(1,1) and '"' == val_string:sub(#val_string,#val_string) then -- double-quote string
        return string.gsub(val_string, '"(.+)"', "%1") -- lua pattern magic: "(.+)" matches all characters between two double-quote marks (no escape chars)
    elseif "'" == val_string:sub(1,1) and "'" == val_string:sub(#val_string,#val_string) then -- single-quote string
        return string.gsub(val_string, "'(.+)'", "%1") -- lua pattern magic: '(.+)' matches all characters between two single-quote marks (no escape chars)
    elseif "{" == val_string:sub(1,1) and "}" == val_string:sub(#val_string,#val_string) then
        return parse_table(string.gsub(val_string, "{(.+)}", "%1"))
    elseif "true" == val_string then
        return true
    elseif "false" == val_string then
        return false
    end
    return tonumber(val_string)
end

local get_parameters_from_file = function(file_name)
    local parameters = {}

    local path = finale.FCString()
    path:SetRunningLuaFolderPath()
    local file_path = path.LuaString .. path_delimiter .. file_name
    if not file_exists(file_path) then
        return parameters
    end

    for line in io.lines(file_path) do
        local comment_at = string.find(line, comment_marker, 1, true) -- true means find raw string rather than lua pattern
        if nil ~= comment_at then
            line = string.sub(line, 1, comment_at-1)
        end
        local delimiter_at = string.find(line, parameter_delimiter, 1, true)
        if nil ~= delimiter_at then
            local name = strip_leading_trailing_whitespace(string.sub(line, 1, delimiter_at-1))
            local val_string = strip_leading_trailing_whitespace(string.sub(line, delimiter_at+1))
            parameters[name] = parse_parameter(val_string)
        end
    end
    
    return parameters
end

--[[
% get_parameters(file_name, parameter_list)

Searches for a file with the input filename in the `script_settings` directory and replaces the default values in `parameter_list` with any that are found in the config file.

@ file_name (string) the file name of the config file (which will be prepended with the `script_settings` directory)
@ parameter_list (table) a table with the parameter name as key and the default value as value
]]
function configuration.get_parameters(file_name, parameter_list)
    local file_parameters = get_parameters_from_file(script_settings_dir .. path_delimiter .. file_name)
    if nil ~= file_parameters then
        for param_name, def_val in pairs(parameter_list) do
            local param_val = file_parameters[param_name]
            if nil ~= param_val then
                parameter_list[param_name] = param_val
            end
        end
    end
end




local standard_key_number_of_steps = 12
local standard_key_major_diatonic_steps = {0, 2, 4, 5, 7, 9, 11}
local standard_key_minor_diatonic_steps = {0, 2, 3, 5, 7, 8, 10}

local max_allowed_abs_alteration = 7 -- Finale cannot represent an alteration outside +/- 7

-- first number is plus_fifths
-- second number is minus_octaves
local diatonic_interval_adjustments = {{0, 0}, {2, -1}, {4, -2}, {-1, 1}, {1, 0}, {3, -1}, {5, -2}, {0, 1}}

local custom_key_sig_config = {
    number_of_steps = standard_key_number_of_steps,
    diatonic_steps = standard_key_major_diatonic_steps,
}

configuration.get_parameters("custom_key_sig.config.txt", custom_key_sig_config)

-- 
-- HELPER functions
-- 

local sign = function(n)
    if n < 0 then
        return -1
    end
    return 1
end

-- this is necessary because the % operator in lua appears always to return a positive value,
-- unlike the % operator in c++
local signed_modulus = function(n, d)
    return sign(n) * (math.abs(n) % d)
end

local get_key = function(note)
    local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
    return cell:GetKeySignature()
end

-- These local functions that take FCKeySignature (key) as their first argument should
-- perhaps move to a key_signature library someday.

-- return number of steps, diatonic steps map, and number of steps in fifth
local get_key_info = function(key)
    local number_of_steps = standard_key_number_of_steps
    local diatonic_steps = standard_key_major_diatonic_steps
    if not key:IsPredefined() then
        number_of_steps = custom_key_sig_config.number_of_steps
        diatonic_steps = custom_key_sig_config.diatonic_steps
    elseif key:IsMinor() then
        diatonic_steps = standard_key_minor_diatonic_steps
    end
    -- 0.5849625 is log(3/2)/log(2), which is how to calculate the 5th per Ere Lievonen.
    -- For basically any practical key sig this calculation comes out to the 5th scale degree,
    -- which is 7 steps for standard keys
    local fifth_steps = math.floor((number_of_steps * 0.5849625) + 0.5)
    return number_of_steps, diatonic_steps, fifth_steps
end

local calc_scale_degree = function(interval, number_of_diatonic_steps_in_key)
    local interval_normalized = signed_modulus(interval, number_of_diatonic_steps_in_key)
    if interval_normalized < 0 then
        interval_normalized = interval_normalized + number_of_diatonic_steps_in_key
    end
    return interval_normalized
end

local calc_steps_between_scale_degrees = function(key, first_disp, second_disp)
    local number_of_steps_in_key, diatonic_steps = get_key_info(key)
    local first_scale_degree = calc_scale_degree(first_disp, #diatonic_steps)
    local second_scale_degree = calc_scale_degree(second_disp, #diatonic_steps)
    local number_of_steps = sign(second_disp - first_disp) *
                                (diatonic_steps[second_scale_degree + 1] - diatonic_steps[first_scale_degree + 1])
    if number_of_steps < 0 then
        number_of_steps = number_of_steps + number_of_steps_in_key
    end
    return number_of_steps
end

local calc_steps_in_alteration = function(key, interval, alteration)
    local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
    local plus_fifths = sign(interval) * alteration * 7 -- number of fifths to add for alteration
    local minus_octaves = sign(interval) * alteration * -4 -- number of octaves to subtract for alteration
    local new_alteration = sign(interval) * ((plus_fifths * fifth_steps) + (minus_octaves * number_of_steps_in_key)) -- new alteration for chromatic interval
    return new_alteration
end

local calc_steps_in_normalized_interval = function(key, interval_normalized)
    local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
    local plus_fifths = diatonic_interval_adjustments[math.abs(interval_normalized) + 1][1] -- number of fifths to add for interval
    local minus_octaves = diatonic_interval_adjustments[math.abs(interval_normalized) + 1][2] -- number of octaves to subtract for alteration
    local number_of_steps_in_interval = sign(interval_normalized) *
                                            ((plus_fifths * fifth_steps) + (minus_octaves * number_of_steps_in_key))
    return number_of_steps_in_interval
end

local simplify_spelling = function(note, min_abs_alteration)
    while math.abs(note.RaiseLower) > min_abs_alteration do
        local curr_sign = sign(note.RaiseLower)
        local curr_abs_disp = math.abs(note.RaiseLower)
        local direction = curr_sign
        local success = transposition.enharmonic_transpose(note, direction, true) -- true: ignore errors (success is always true)
        if not success then
            return false
        end
        if math.abs(note.RaiseLower) >= curr_abs_disp then
            return transposition.enharmonic_transpose(note, -1 * direction)
        end
        if curr_sign ~= sign(note.RaiseLower) then
            break
        end
    end
    return true
end

-- 
-- DIATONIC transposition (affect only Displacement)
-- 

--[[
% diatonic_transpose(note, interval)

Transpose the note diatonically by the given interval displacement.

@ note (FCNote) input and modified output
@ interval (number) 0 = unison, 1 = up a diatonic second, -2 = down a diatonic third, etc.
]]
function transposition.diatonic_transpose(note, interval)
    note.Displacement = note.Displacement + interval
end

--[[
% change_octave(note, number_of_octaves)

Transpose the note by the given number of octaves.

@ note (FCNote) input and modified output
@ number_of_octaves (number) 0 = no change, 1 = up an octave, -2 = down 2 octaves, etc.
]]
function transposition.change_octave(note, number_of_octaves)
    transposition.diatonic_transpose(note, 7 * number_of_octaves)
end

--
-- ENHARMONIC transposition
--

--[[
% enharmonic_transpose(note, direction, ignore_error)

Transpose the note enharmonically in the given direction. In some microtone systems this yields a different result than transposing by a diminished 2nd.
Failure occurs if the note's `RaiseLower` value exceeds an absolute value of 7. This is a hard-coded limit in Finale.

@ note (FCNote) input and modified output
@ direction (number) positive = up, negative = down (normally 1 or -1, but any positive or negative numbers work)
@ [ignore_error] (boolean) default false. If true, always return success. External callers should omit this parameter.
: (boolean) success or failure
]]
function transposition.enharmonic_transpose(note, direction, ignore_error)
    ignore_error = ignore_error or false
    local curr_disp = note.Displacement
    local curr_alt = note.RaiseLower
    local key = get_key(note)
    local key_step_enharmonic = calc_steps_between_scale_degrees(
                                    key, note.Displacement, note.Displacement + sign(direction))
    transposition.diatonic_transpose(note, sign(direction))
    note.RaiseLower = note.RaiseLower - sign(direction) * key_step_enharmonic
    if ignore_error then
        return true
    end
    if math.abs(note.RaiseLower) > max_allowed_abs_alteration then
        note.Displacement = curr_disp
        note.RaiseLower = curr_alt
        return false
    end
    return true
end

-- 
-- CHROMATIC transposition (affect Displacement and RaiseLower)
-- 

--[[
% chromatic_transpose(note, interval, alteration, simplify)

Transposes a note chromatically by the input chromatic interval. Supports custom key signatures
and microtone systems by means of a `custom_key_sig.config.txt` file. In Finale, chromatic intervals
are defined by a diatonic displacement (0 = unison, 1 = second, 2 = third, etc.) and a chromatic alteration.
Major and perfect intervals have a chromatic alteration of 0. So for example, `{2, -1}` is up a minor third, `{3, 0}`
is up a perfect fourth, `{5, 1}` is up an augmented sixth, etc. Reversing the signs of both values in the pair
allows for downwards transposition.

@ note (FCNote) the note to transpose
@ interval (number) the diatonic displacement (negative for transposing down)
@ alteration (number) the chromatic alteration that defines the chromatic interval (reverse sign for transposing down)
@ [simplify] (boolean) if present and true causes the spelling of the transposed note to be simplified
: (boolean) success or failure (see `enharmonic_transpose` for what causes failure)
--]]
function transposition.chromatic_transpose(note, interval, alteration, simplify)
    simplify = simplify or false
    local curr_disp = note.Displacement
    local curr_alt = note.RaiseLower

    local key = get_key(note)
    local number_of_steps, diatonic_steps, fifth_steps = get_key_info(key)
    local interval_normalized = signed_modulus(interval, #diatonic_steps)
    local steps_in_alteration = calc_steps_in_alteration(key, interval, alteration)
    local steps_in_interval = calc_steps_in_normalized_interval(key, interval_normalized)
    local steps_in_diatonic_interval = calc_steps_between_scale_degrees(
                                           key, note.Displacement, note.Displacement + interval_normalized)
    local effective_alteration = steps_in_alteration + steps_in_interval - sign(interval) * steps_in_diatonic_interval
    transposition.diatonic_transpose(note, interval)
    note.RaiseLower = note.RaiseLower + effective_alteration

    local min_abs_alteration = max_allowed_abs_alteration
    if simplify then
        min_abs_alteration = 0
    end
    local success = simplify_spelling(note, min_abs_alteration)
    if not success then -- if Finale can't represent the transposition, revert it to original value
        note.Displacement = curr_disp
        note.RaiseLower = curr_alt
    end
    return success
end

--[[
% stepwise_transpose(note, number_of_steps)

Transposes the note by the input number of steps and simplifies the spelling.
For predefined key signatures, each step is a half-step.
For microtone systems defined with custom key signatures and matching options in the `custom_key_sig.config.txt` file,
each step is the smallest division of the octave defined by the custom key signature.

@ note (FCNote) input and modified output
@ number_of_steps (number) positive = up, negative = down
: (boolean) success or failure (see `enharmonic_transpose` for what causes failure)
]]
function transposition.stepwise_transpose(note, number_of_steps)
    local curr_disp = note.Displacement
    local curr_alt = note.RaiseLower
    note.RaiseLower = note.RaiseLower + number_of_steps
    local success = simplify_spelling(note, 0)
    if not success then -- if Finale can't represent the transposition, revert it to original value
        note.Displacement = curr_disp
        note.RaiseLower = curr_alt
    end
    return success
end

--[[
% chromatic_major_third_down(note)

Transpose the note down by a major third.

@ note (FCNote) input and modified output
]]
function transposition.chromatic_major_third_down(note)
    transposition.chromatic_transpose(note, -2, -0)
end

--[[
% chromatic_perfect_fourth_up(note)

Transpose the note up by a perfect fourth.

@ note (FCNote) input and modified output
]]
function transposition.chromatic_perfect_fourth_up(note)
    transposition.chromatic_transpose(note, 3, 0)
end

--[[
% chromatic_perfect_fifth_down(note)

Transpose the note down by a perfect fifth.

@ note (FCNote) input and modified output
]]
function transposition.chromatic_perfect_fifth_down(note)
    transposition.chromatic_transpose(note, -4, -0)
end



--[[
$module Notehead
]]

-- A collection of helpful JW Lua notehead scripts
-- Simply import this file to another Lua script to use any of these scripts
local notehead = {}

--  Author: Robert Patterson
--  Date: March 5, 2021

--[[
$module Configuration

This library implements a UTF-8 text file scheme for configuration as follows:

- Comments start with `--`
- Leading, trailing, and extra whitespace is ignored
- Each parameter is named and delimited as follows:
`<parameter-name> = <parameter-value>`

Parameter values may be:

- Strings delimited with either single- or double-quotes
- Tables delimited with `{}` that may contain strings, booleans, or numbers
- Booleans (`true` or `false`)
- Numbers

Currently the following are not supported:

- Tables embedded within tables
- Tables containing strings that contain commas

A sample configuration file might be:

```lua
-- Configuration File for "Hairpin and Dynamic Adjustments" script
--
left_dynamic_cushion 		= 12		--evpus
right_dynamic_cushion		= -6		--evpus
```
]]

local configuration = {}

local script_settings_dir = "script_settings" -- the parent of this directory is the running lua path
local comment_marker = "--"
local parameter_delimiter = "="
local path_delimiter = "/"

local file_exists = function(file_path)
    local f = io.open(file_path,"r")
    if nil ~= f then
        io.close(f)
        return true
    end
    return false
end

local strip_leading_trailing_whitespace = function (str)
    return str:match("^%s*(.-)%s*$") -- lua pattern magic taken from the Internet
end

local parse_parameter -- forward function declaration

local parse_table = function(val_string)
    local ret_table = {}
    for element in val_string:gmatch('[^,%s]+') do  -- lua pattern magic taken from the Internet
        local parsed_element = parse_parameter(element)
        table.insert(ret_table, parsed_element)
    end
    return ret_table
end

parse_parameter = function(val_string)
    if '"' == val_string:sub(1,1) and '"' == val_string:sub(#val_string,#val_string) then -- double-quote string
        return string.gsub(val_string, '"(.+)"', "%1") -- lua pattern magic: "(.+)" matches all characters between two double-quote marks (no escape chars)
    elseif "'" == val_string:sub(1,1) and "'" == val_string:sub(#val_string,#val_string) then -- single-quote string
        return string.gsub(val_string, "'(.+)'", "%1") -- lua pattern magic: '(.+)' matches all characters between two single-quote marks (no escape chars)
    elseif "{" == val_string:sub(1,1) and "}" == val_string:sub(#val_string,#val_string) then
        return parse_table(string.gsub(val_string, "{(.+)}", "%1"))
    elseif "true" == val_string then
        return true
    elseif "false" == val_string then
        return false
    end
    return tonumber(val_string)
end

local get_parameters_from_file = function(file_name)
    local parameters = {}

    local path = finale.FCString()
    path:SetRunningLuaFolderPath()
    local file_path = path.LuaString .. path_delimiter .. file_name
    if not file_exists(file_path) then
        return parameters
    end

    for line in io.lines(file_path) do
        local comment_at = string.find(line, comment_marker, 1, true) -- true means find raw string rather than lua pattern
        if nil ~= comment_at then
            line = string.sub(line, 1, comment_at-1)
        end
        local delimiter_at = string.find(line, parameter_delimiter, 1, true)
        if nil ~= delimiter_at then
            local name = strip_leading_trailing_whitespace(string.sub(line, 1, delimiter_at-1))
            local val_string = strip_leading_trailing_whitespace(string.sub(line, delimiter_at+1))
            parameters[name] = parse_parameter(val_string)
        end
    end
    
    return parameters
end

--[[
% get_parameters(file_name, parameter_list)

Searches for a file with the input filename in the `script_settings` directory and replaces the default values in `parameter_list` with any that are found in the config file.

@ file_name (string) the file name of the config file (which will be prepended with the `script_settings` directory)
@ parameter_list (table) a table with the parameter name as key and the default value as value
]]
function configuration.get_parameters(file_name, parameter_list)
    local file_parameters = get_parameters_from_file(script_settings_dir .. path_delimiter .. file_name)
    if nil ~= file_parameters then
        for param_name, def_val in pairs(parameter_list) do
            local param_val = file_parameters[param_name]
            if nil ~= param_val then
                parameter_list[param_name] = param_val
            end
        end
    end
end



--[[
$module Library
]]
local library = {}

--[[
% group_overlaps_region(staff_group, region)

Returns true if the input staff group overlaps with the input music region, otherwise false.

@ staff_group (FCGroup)
@ region (FCMusicRegion)
: (boolean)
]]
function library.group_overlaps_region(staff_group, region)
    if region:IsFullDocumentSpan() then
        return true
    end
    local staff_exists = false
    local sys_staves = finale.FCSystemStaves()
    sys_staves:LoadAllForRegion(region)
    for sys_staff in each(sys_staves) do
        if staff_group:ContainsStaff(sys_staff:GetStaff()) then
            staff_exists = true
            break
        end
    end
    if not staff_exists then
        return false
    end
    if (staff_group.StartMeasure > region.EndMeasure) or (staff_group.EndMeasure < region.StartMeasure) then
        return false
    end
    return true
end

--[[
% group_is_contained_in_region(staff_group, region)

Returns true if the entire input staff group is contained within the input music region.
If the start or end staff are not visible in the region, it returns false.

@ staff_group (FCGroup)
@ region (FCMusicRegion)
: (boolean)
]]
function library.group_is_contained_in_region(staff_group, region)
    if not region:IsStaffIncluded(staff_group.StartStaff) then
        return false
    end
    if not region:IsStaffIncluded(staff_group.EndStaff) then
        return false
    end
    return true
end

--[[
% staff_group_is_multistaff_instrument(staff_group)

Returns true if the entire input staff group is a multistaff instrument.

@ staff_group (FCGroup)
: (boolean)
]]
function library.staff_group_is_multistaff_instrument(staff_group)
    local multistaff_instruments = finale.FCMultiStaffInstruments()
    multistaff_instruments:LoadAll()
    for inst in each(multistaff_instruments) do
        if inst:ContainsStaff(staff_group.StartStaff) and (inst.GroupID == staff_group:GetItemID()) then
            return true
        end
    end
    return false
end

--[[
% get_selected_region_or_whole_doc()

Returns a region that contains the selected region if there is a selection or the whole document if there isn't.
SIDE-EFFECT WARNING: If there is no selected region, this function also changes finenv.Region() to the whole document.

: (FCMusicRegion)
]]
function library.get_selected_region_or_whole_doc()
    local sel_region = finenv.Region()
    if sel_region:IsEmpty() then
        sel_region:SetFullDocument()
    end
    return sel_region
end

--[[
% get_first_cell_on_or_after_page(page_num)

Returns the first FCCell at the top of the input page. If the page is blank, it returns the first cell after the input page.

@ page_num (number)
: (FCCell)
]]
function library.get_first_cell_on_or_after_page(page_num)
    local curr_page_num = page_num
    local curr_page = finale.FCPage()
    local got1 = false
    --skip over any blank pages
    while curr_page:Load(curr_page_num) do
        if curr_page:GetFirstSystem() > 0 then
            got1 = true
            break
        end
        curr_page_num = curr_page_num + 1
    end
    if got1 then
        local staff_sys = finale.FCStaffSystem()
        staff_sys:Load(curr_page:GetFirstSystem())
        return finale.FCCell(staff_sys.FirstMeasure, staff_sys.TopStaff)
    end
    --if we got here there were nothing but blank pages left at the end
    local end_region = finale.FCMusicRegion()
    end_region:SetFullDocument()
    return finale.FCCell(end_region.EndMeasure, end_region.EndStaff)
end

--[[
% get_top_left_visible_cell()

Returns the topmost, leftmost visible FCCell on the screen, or the closest possible estimate of it.

: (FCCell)
]]
function library.get_top_left_visible_cell()
    if not finenv.UI():IsPageView() then
        local all_region = finale.FCMusicRegion()
        all_region:SetFullDocument()
        return finale.FCCell(finenv.UI():GetCurrentMeasure(), all_region.StartStaff)
    end
    return library.get_first_cell_on_or_after_page(finenv.UI():GetCurrentPage())
end

--[[
% get_top_left_selected_or_visible_cell()

If there is a selection, returns the topmost, leftmost cell in the selected region.
Otherwise returns the best estimate for the topmost, leftmost currently visible cell.

: (FCCell)
]]
function library.get_top_left_selected_or_visible_cell()
    local sel_region = finenv.Region()
    if not sel_region:IsEmpty() then
        return finale.FCCell(sel_region.StartMeasure, sel_region.StartStaff)
    end
    return library.get_top_left_visible_cell()
end

--[[
% is_default_measure_number_visible_on_cell (meas_num_region, cell, staff_system, current_is_part)

Returns true if measure numbers for the input region are visible on the input cell for the staff system.

@ meas_num_region (FCMeasureNumberRegion)
@ cell (FCCell)
@ staff_system (FCStaffSystem)
@ current_is_part (boolean) true if the current view is a linked part, otherwise false
: (boolean)
]]
function library.is_default_measure_number_visible_on_cell (meas_num_region, cell, staff_system, current_is_part)
    local staff = finale.FCCurrentStaffSpec()
    if not staff:LoadForCell(cell, 0) then
        return false
    end
    if meas_num_region:GetShowOnTopStaff() and (cell.Staff == staff_system.TopStaff) then
        return true
    end
    if meas_num_region:GetShowOnBottomStaff() and (cell.Staff == staff_system:CalcBottomStaff()) then
        return true
    end
    if staff.ShowMeasureNumbers then
        return not meas_num_region:GetExcludeOtherStaves(current_is_part)
    end
    return false
end

--[[
% is_default_number_visible_and_left_aligned (meas_num_region, cell, system, current_is_part, is_for_multimeasure_rest)

Returns true if measure number for the input cell is visible and left-aligned.

@ meas_num_region (FCMeasureNumberRegion)
@ cell (FCCell)
@ system (FCStaffSystem)
@ current_is_part (boolean) true if the current view is a linked part, otherwise false
@ is_for_multimeasure_rest (boolean) true if the current cell starts a multimeasure rest
: (boolean)
]]
function library.is_default_number_visible_and_left_aligned (meas_num_region, cell, system, current_is_part, is_for_multimeasure_rest)
    if meas_num_region.UseScoreInfoForParts then
        current_is_part = false
    end
    if is_for_multimeasure_rest and meas_num_region:GetShowOnMultiMeasureRests(current_is_part) then
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetMultiMeasureAlignment(current_is_part)) then
            return false
        end
    elseif (cell.Measure == system.FirstMeasure) then
        if not meas_num_region:GetShowOnSystemStart() then
            return false
        end
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetStartAlignment(current_is_part)) then
            return false
        end
    else
        if not meas_num_region:GetShowMultiples(current_is_part) then
            return false
        end
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetMultipleAlignment(current_is_part)) then
            return false
        end
    end
    return library.is_default_measure_number_visible_on_cell (meas_num_region, cell, system, current_is_part)
end

--[[
% update_layout(from_page, unfreeze_measures)

Updates the page layout.

@ [from_page] (number) page to update from, defaults to 1
@ [unfreeze_measures] (boolean) defaults to false
]]
function library.update_layout(from_page, unfreeze_measures)
    from_page = from_page or 1
    unfreeze_measures = unfreeze_measures or false
    local page = finale.FCPage()
    if page:Load(from_page) then
        page:UpdateLayout(unfreeze_measures)
    end
end

--[[
% get_current_part()

Returns the currently selected part or score.

: (FCPart)
]]
function library.get_current_part()
    local parts = finale.FCParts()
    parts:LoadAll()
    return parts:GetCurrent()
end

--[[
% get_page_format_prefs()

Returns the default page format prefs for score or parts based on which is currently selected.

: (FCPageFormatPrefs)
]]
function library.get_page_format_prefs()
    local current_part = library.get_current_part()
    local page_format_prefs = finale.FCPageFormatPrefs()
    local success = false
    if current_part:IsScore() then
        success = page_format_prefs:LoadScore()
    else
        success = page_format_prefs:LoadParts()
    end
    return page_format_prefs, success
end

--[[
% get_smufl_metadata_file(font_info)

@ [font_info] (FCFontInfo) if non-nil, the font to search for; if nil, search for the Default Music Font
: (file handle|nil)
]]
function library.get_smufl_metadata_file(font_info)
    if nil == font_info then
        font_info = finale.FCFontInfo()
        font_info:LoadFontPrefs(finale.FONTPREF_MUSIC)
    end

    local try_prefix = function(prefix, font_info)
        local file_path = prefix .. "/SMuFL/Fonts/" .. font_info.Name .. "/" .. font_info.Name .. ".json"
        return io.open(file_path, "r")
    end

    local smufl_json_user_prefix = ""
    if finenv.UI():IsOnWindows() then
        smufl_json_user_prefix = os.getenv("LOCALAPPDATA")
    else
        smufl_json_user_prefix = os.getenv("HOME") .. "/Library/Application Support"
    end
    local user_file = try_prefix(smufl_json_user_prefix, font_info)
    if nil ~= user_file then
        return user_file
    end

    local smufl_json_system_prefix = "/Library/Application Support"
    if finenv.UI():IsOnWindows() then
        smufl_json_system_prefix = os.getenv("COMMONPROGRAMFILES") 
    end
    return try_prefix(smufl_json_system_prefix, font_info)
end

--[[
% is_font_smufl_font(font_info)

@ [font_info] (FCFontInfo) if non-nil, the font to check; if nil, check the Default Music Font
: (boolean)
]]
function library.is_font_smufl_font(font_info)
    local smufl_metadata_file = library.get_smufl_metadata_file(font_info)
    if nil ~= smufl_metadata_file then
        io.close(smufl_metadata_file)
        return true
    end
    return false
end




local config = {
    diamond_open                = 79,
    diamond_closed              = 79,   -- per Elaine Gould, use open diamond even on closed regular notes, but allow it to be overridden
    diamond_resize              = 110,
    diamond_whole_offset        = 5,
    diamond_breve_offset        = 14
}

-- Default to SMuFL characters for SMuFL font (without needing a config file)
if library.is_font_smufl_font() then
    config.diamond_open = 0xe0e1
    config.diamond_closed = 0xe0e1  -- (in config) override to 0xe0e2 for closest matching closed diamond if you want to disregard Elain Gould and use a closed notehead
end

configuration.get_parameters("notehead.config.txt", config)

--[[
% change_shape(note, shape)

Changes the given notehead to a specified notehead descriptor string. Currently only supports "diamond".

@ note (FCNote)
@ shape (lua string)

: (FCNoteheadMod) the new notehead mod record created
]]
function notehead.change_shape(note, shape)
    local notehead = finale.FCNoteheadMod()
    notehead:EraseAt(newnote)

    if shape == "diamond" then
        local entry = note:GetEntry()
        local offset = 0
        local notehead_char = config.diamond_open
        if entry.Duration >= finale.BREVE then
            offset = config.diamond_breve_offset
        elseif entry.Duration >= finale.WHOLE_NOTE then
            offset = config.diamond_whole_offset
        elseif entry.Duration < finale.HALF_NOTE then
            notehead_char = config.diamond_closed
        end
        if (0 ~= offset) then
            if entry:CalcStemUp() then
                notehead.HorizontalPos = -1*offset
            else
                notehead.HorizontalPos = offset
            end
        end
        notehead.CustomChar = notehead_char
        notehead.Resize = config.diamond_resize
    end

    notehead:SaveAt(note)
end



--[[
$module Note Entry
]]
local note_entry = {}

-- This function may not have been used anywhere, though it has been tested and works.
-- If you use this function, remove this comment.
-- If you remove this function, be sure to check that it still isn't used.
--[[
% get_music_region(entry)

Returns an intance of `FCMusicRegion` that corresponds to the metric location of the input note entry.

@ entry (FCNoteEntry)
: (FCMusicRegion)
]]
function note_entry.get_music_region(entry)
    local exp_region = finale.FCMusicRegion()
    exp_region:SetCurrentSelection() -- called to match the selected IU list (e.g., if using Staff Sets)
    exp_region.StartStaff = entry.Staff
    exp_region.EndStaff = entry.Staff
    exp_region.StartMeasure = entry.Measure
    exp_region.EndMeasure = entry.Measure
    exp_region.StartMeasurePos = entry.MeasurePos
    exp_region.EndMeasurePos = entry.MeasurePos
    return exp_region
end

--entry_metrics can be omitted, in which case they are constructed and released here
--return entry_metrics, loaded_here
local use_or_get_passed_in_entry_metrics = function(entry, entry_metrics)
    if nil ~= entry_metrics then
        return entry_metrics, false
    end
    entry_metrics = finale.FCEntryMetrics()
    if entry_metrics:Load(entry) then
        return entry_metrics, true
    end
    return nil, false
end

-- This function may not have been used anywhere, though it has been tested and works.
-- If you use this function, remove this comment.
-- If you remove this function, be sure to check that it still isn't used.
--[[
% get_evpu_notehead_height(entry)

Returns the calculated height of the notehead rectangle.

@ entry (FCNoteEntry)

: (number) the EVPU height
]]
function note_entry.get_evpu_notehead_height(entry)
    local highest_note = entry:CalcHighestNote(nil)
    local lowest_note = entry:CalcLowestNote(nil)
    local evpu_height = (2 + highest_note:CalcStaffPosition() - lowest_note:CalcStaffPosition()) * 12 -- 12 evpu per staff step; add 2 staff steps to accommodate for notehead height at top and bottom
    return evpu_height
end

--[[
% get_top_note_position(entry, entry_metrics)

Returns the vertical page coordinate of the top of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_top_note_position(entry, entry_metrics)
    local retval = -math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if not entry:CalcStemUp() then
        retval = entry_metrics.TopPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling*evpu_height)/10000) + 0.5)
            retval = entry_metrics.BottomPosition + scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% get_bottom_note_position(entry, entry_metrics)

Returns the vertical page coordinate of the bottom of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_bottom_note_position(entry, entry_metrics)
    local retval = math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if entry:CalcStemUp() then
        retval = entry_metrics.BottomPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling*evpu_height)/10000) + 0.5)
            retval = entry_metrics.TopPosition - scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% calc_widths(entry)

Get the widest left-side notehead width and widest right-side notehead width.

@ entry (FCNoteEntry)
: (number, number) widest left-side notehead width and widest right-side notehead width
]]
function note_entry.calc_widths(entry)
    local left_width = 0
    local right_width = 0
    for note in each(entry) do
        local note_width = note:CalcNoteheadWidth()
        if note_width > 0 then
            if note:CalcRightsidePlacement() then
                if note_width > right_width then
                    right_width = note_width
                end
            else
                if note_width > left_width then
                    left_width = note_width
                end
            end
        end
    end
    return left_width, right_width
end

-- These functions return the offset for an expression handle.
-- Expression handles are vertical when they are left-aligned
-- with the primary notehead rectangle.

--[[
% calc_left_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Left of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_all_noteheads(entry)
    if entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return -left
end

--[[
% calc_left_of_primary_notehead(entry)

Calculates the handle offset for an expression with "Left of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_primary_notehead(entry)
    return 0
end

--[[
% calc_center_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Center of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    local width_centered = (left + right) / 2
    if not entry:CalcStemUp() then
        width_centered = width_centered - left
    end
    return width_centered
end

--[[
% calc_center_of_primary_notehead(entry)

Calculates the handle offset for an expression with "Center of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_primary_notehead(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left / 2
    end
    return right / 2
end

--[[
% calc_stem_offset(entry)

Calculates the offset of the stem from the left edge of the notehead rectangle. Eventually the PDK Framework may be able to provide this instead.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset of stem from the left edge of the notehead rectangle.
]]
function note_entry.calc_stem_offset(entry)
    if not entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return left
end

--[[
% calc_right_of_all_noteheads(entry)

Calculates the handle offset for an expression with "Right of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_right_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left + right
    end
    return right
end

--[[
% calc_note_at_index(entry, note_index)

This function assumes `for note in each(note_entry)` always iterates in the same direction.
(Knowing how the Finale PDK works, it probably iterates from bottom to top note.)
Currently the PDK Framework does not seem to offer a better option.

@ entry (FCNoteEntry)
@ note_index (number) the zero-based index
]]
function note_entry.calc_note_at_index(entry, note_index)
    local x = 0
    for note in each(entry) do
        if x == note_index then
            return note
        end
        x = x + 1
    end
    return nil
end

--[[
% stem_sign(entry)

This is useful for many x,y positioning fields in Finale that mirror +/-
based on stem direction.

@ entry (FCNoteEntry)
: (number) 1 if upstem, -1 otherwise
]]
function note_entry.stem_sign(entry)
    if entry:CalcStemUp() then
        return 1
    end
    return -1
end

--[[
% duplicate_note(note)

@ note (FCNote)
: (FCNote | nil) reference to added FCNote or `nil` if not success
]]
function note_entry.duplicate_note(note)
    local new_note = note.Entry:AddNewNote()
    if nil ~= new_note then
        new_note.Displacement = note.Displacement
        new_note.RaiseLower = note.RaiseLower
        new_note.Tie = note.Tie
        new_note.TieBackwards = note.TieBackwards
    end
    return new_note
end

--[[
% delete_note(note)

Removes the specified FCNote from its associated FCNoteEntry.

@ note (FCNote)
: (boolean) true if success
]]
function note_entry.delete_note(note)
    local entry = note.Entry
    if nil == entry then
        return false
    end

    -- attempt to delete all associated entry-detail mods, but ignore any failures
    finale.FCAccidentalMod():EraseAt(note)
    finale.FCCrossStaffMod():EraseAt(note)
    finale.FCDotMod():EraseAt(note)
    finale.FCNoteheadMod():EraseAt(note)
    finale.FCPercussionNoteMod():EraseAt(note)
    finale.FCTablatureNoteMod():EraseAt(note)
    --finale.FCTieMod():EraseAt(note)  -- FCTieMod is not currently lua supported, but leave this here in case it ever is

    return entry:DeleteNote(note)
end

--[[
% calc_spans_number_of_octaves(entry)

Calculates the numer of octaves spanned by a chord (considering only staff positions, not accidentals).

@ entry (FCNoteEntry) the entry to calculate from
: (number) of octaves spanned
]]
function note_entry.calc_spans_number_of_octaves(entry)
    local top_note = entry:CalcHighestNote(nil)
    local bottom_note = entry:CalcLowestNote(nil)
    local displacement_diff = top_note.Displacement - bottom_note.Displacement
    local num_octaves = math.ceil(displacement_diff / 7)
    return num_octaves
end

--[[
% add_augmentation_dot(entry)

Adds an augentation dot to the entry. This works even if the entry already has one or more augmentation dots.

@ entry (FCNoteEntry) the entry to which to add the augmentation dot
]]
function note_entry.add_augmentation_dot(entry)
    entry.Duration = bit32.bor(entry.Duration, bit32.rshift(entry.Duration, 1))
end

--[[
% get_next_same_v(entry)

Returns the next entry in the same V1 or V2 as the input entry.
If the input entry is V2, only the current V2 launch is searched.
If the input entry is V1, only the current measure and layer is searched.

@ entry (FCNoteEntry) the entry to process
: (FCNoteEntry) the next entry or `nil` in none
]]
function note_entry.get_next_same_v(entry)
    local next_entry = entry:Next()
    if entry.Voice2 then
        if (nil ~= next_entry) and next_entry.Voice2 then
            return next_entry
        end
        return nil
    end
    if entry.Voice2Launch then
        while (nil ~= next_entry) and next_entry.Voice2 do
            next_entry = next_entry:Next()
        end
    end
    return next_entry
end




function pitch_transform_harmonics_fourth()
    for entry in eachentrysaved(finenv.Region()) do
        if (entry.Count == 1) and (not entry:IsRest()) then
            articulation.delete_from_entry_by_char_num(entry, 111)
            local note = entry:CalcLowestNote(nil)
            transposition.change_octave(note, -2)
            local new_note = note_entry.duplicate_note(note)
            transposition.chromatic_perfect_fourth_up(new_note)
        end
    end
    -- we have to change the note shapes in a separate pass because we may need to get the stem direction
    -- after transposition, which means the entry has to be saved first
    for entry in eachentrysaved(finenv.Region()) do
        if (entry.Count == 2) then
            local note = entry:CalcHighestNote(nil)
            notehead.change_shape(note, "diamond")
        end
    end
end

pitch_transform_harmonics_fourth()
