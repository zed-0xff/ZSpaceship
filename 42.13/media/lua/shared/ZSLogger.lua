ZSLogger = ZSLogger or {}

ZSLogger.DEBUG = 1
ZSLogger.INFO  = 2
ZSLogger.WARN  = 3
ZSLogger.ERROR = 4

ZSLogger.DEFAULT_LEVEL = ZSLogger.DEBUG

local prefix_tbl = {
    [ZSLogger.DEBUG] = "[d] ",
    [ZSLogger.INFO]  = "[.] ",
    [ZSLogger.WARN]  = "[?] ",
    [ZSLogger.ERROR] = "[!] ",
}

function ZSLogger:print(level, ...)
    if self.level > level then return end

    local prefix = prefix_tbl[level] or prefix_tbl[ZSLogger.WARN]
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

function ZSLogger:debug(...) self:print(ZSLogger.DEBUG, ...) end
function ZSLogger:info(...)  self:print(ZSLogger.INFO,  ...) end
function ZSLogger:warn(...)  self:print(ZSLogger.WARN,  ...) end
function ZSLogger:error(...) self:print(ZSLogger.ERROR, ...) end

local _loggers = {}

function ZSLogger.new(id, level)
    if _loggers[id] then return _loggers[id] end

    local logger = {}
    logger.id    = id
    logger.level = level or ZSLogger.DEFAULT_LEVEL
    setmetatable(logger, { __index = ZSLogger })
    _loggers[id] = logger

    return logger
end
