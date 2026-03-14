local version = 1.0
if type(ZBLogger_VERSION) == "number" and ZBLogger_VERSION >= version then return end

print("ZBLogger v" .. tostring(version) .. " init")
ZBLogger_VERSION = version

ZBLogger = {} -- intentionally not using 'ZBLogger = ZBLogger or {}' to avoid cross-version method pollution

ZBLogger.DEBUG = 1
ZBLogger.INFO  = 2
ZBLogger.WARN  = 3
ZBLogger.ERROR = 4

ZBLogger.DEFAULT_LEVEL = ZBLogger.INFO

local prefix_tbl = {
    [ZBLogger.DEBUG] = "[d] ",
    [ZBLogger.INFO]  = "[.] ",
    [ZBLogger.WARN]  = "[?] ",
    [ZBLogger.ERROR] = "[!] ",
}

function ZBLogger:print(level, ...)
    if self.level > level then return end

    local prefix = prefix_tbl[level] or prefix_tbl[ZBLogger.WARN]
    if self.id then
        prefix = prefix .. "[" .. self.id .. "] "
    end
    local args = { ... }
    if #args > 1 then
        for i = 2, #args do
            if type(args[i]) == "table" then
                args[i] = serialize(args[i]) -- syntax sugar: "%s" prints table contents
            end
        end
    end
    print(prefix .. string.format(unpack(args)))
end

function ZBLogger:debug(...) self:print(ZBLogger.DEBUG, ...) end
function ZBLogger:info(...)  self:print(ZBLogger.INFO,  ...) end
function ZBLogger:warn(...)  self:print(ZBLogger.WARN,  ...) end
function ZBLogger:error(...) self:print(ZBLogger.ERROR, ...) end

local _loggers = {}

function ZBLogger.new(id, level)
    if _loggers[id] then return _loggers[id] end

    local logger = {}
    logger.id    = id
    logger.level = level or ZBLogger.DEFAULT_LEVEL
    setmetatable(logger, { __index = ZBLogger })
    _loggers[id] = logger

    return logger
end
