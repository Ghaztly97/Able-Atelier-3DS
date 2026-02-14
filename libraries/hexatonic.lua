--[[
    HexManiac
    Originally created and published by LavenderTheGreat in 2019
    Modified by Pongles 2019-2020
]]--
local moduleFactory = {}
setmetatable(moduleFactory, {
    __call = function(t, ...)
        return t.init(...)
    end
})

local split = function(str, start)
    return tonumber(string.sub(str, start, start+1), 16)
end

local convert = function(num)
    if love._version_major < 11 then return num
    else return (1/255)*num end
end

local clamp = function(num, low, high)
    return math.min(math.max(low, num), high)
end

function moduleFactory.init(logger)
    local module = {}
    module.__name = "hexmaniac"
    module.__version_major = 0
    module.__version_minor = 2
    module.__version = function() return module.__version_major.."."..module.__version_minor end

    function module:rgb(str)
        local color = {}
        for i=1, 5, 2 do
            table.insert(color, convert(split(str, i)))
        end
        return color
    end

    function module:rgba(str)
        local color = self:rgb(string.sub(str, 1, 6))
        table.insert(color, convert(split(str, 7)))
        return color
    end

    function module:rgbo(str, op)
        local color = self:rgb(str)
        table.insert(color, op)
        return color
    end

    function module:log(str)
        logger.log("["..self.__name.."v"..tostring(self.__version()).."] " .. str)
    end

    function module:error(str)
        logger.error("["..self.__name.."v"..tostring(self.__version()).."] " .. str)
    end

    function module:alert(str)
        logger.alert("["..self.__name.."v"..tostring(self.__version()).."] " .. str)
    end

    function module:hexValidation(hex)
        if type(hex) ~= "string" then
            self:error("Invalid Argument. Hex requires type 'string' of length 6 or 8. Instead got type '" .. type(hex) .. "' (" .. tostring(hex) .. ")")
            return
        end
        hex = string.upper(hex)
        local length = string.len(hex)
        if (length ~= 8) then
            if (length == 6) then
                hex = hex .. "FF"
            end
        else
            self:error("Invalid Argument. Hex requires type 'string' of length 6 or 8. Instead got type '" .. type(hex) .. "' (" .. tostring(hex) .. ")")
            return
        end

        if string.find(hex, "[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]") == nil then
            self:error("Invalid Argument. Expected valid Hex Color Code, recieved: " .. hex)
            return
        end
        return hex
    end

    function module:opacityValidation(opacity)
        if type(opacity) ~= "number" then
            self:error("Invalid Argument. Opacity requires type 'number'. Instead got type '" .. type(opacity) .. "' (" .. tostring(opacity) .. ")")
        end
        return clamp(opacity, 0, 1)
    end

    setmetatable(module, {
        __call = function(mod, hex, opacity)
            hex = mod:hexValidation(hex)
            if opacity == nil then return mod:rgba(hex) end
            opacity = mod:opacityValidation(opacity)
            return mod:rgbo(string.sub(hex, 1, 6), opacity)
        end,
        __tostring = function(mod) return mod.__name .. "v" .. mod.__version() end,
        __index = function(mod, index)
            mod:alert("Index Not Found. Attempted getting index '" .. index .. "' on table '" .. mod.__name .. "'")
        end,
        __newindex = function(mod, index, value)
            mod:alert("Operation Not Allowed. Attempted setting of value ".. value .." on index "..index.. " on table " .. mod.__name .. "'")
        end
    })

    return module
end

return moduleFactory