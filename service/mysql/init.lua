local skynet = require "skynet"
local s = require "service"

local max_pool_size = tonumber(skynet.getenv("MYSQL_POOL_SIZE")) or 100
local connection_timeout = tonumber(skynet.getenv("MYSQL_CONN_TIMEOUT")) or 100
local user = skynet.getenv("MYSQL_USER") or "root"
local pwd  = skynet.getenv("MYSQL_PWD") or "root"
local db_name = skynet.getenv("MYSQL_DATABASE") or "qqdzz"
local ip_addr = skynet.getenv("MYSQL_IP_ADDR") or "127.0.0.1"

local pool -- 连接池

local function create_pool()
    pool = {}
    pool.idle = {} -- 空闲连接队列
    pool.busy = {} -- 忙碌连接队列
    pool.size = 0 -- 当前连接数
    pool.max_size = max_pool_size -- 最大连接数
    pool.timeout = connection_timeout -- 连接超时时间
end

local function get_mysql()
    local mysql_conf = {
        host = ip_addr,
        port = 3306,
        database = db_name,
        user = user,
        password = pwd,
        max_packet_size = 1024 * 1024
    }
    return mysql.connect(mysql_conf)
end

local function release_mysql(db)
    db:set_keepalive(pool.timeout, pool.max_size)
end

local function connect_mysql()
    local db = get_mysql()
    if not db then
        skynet.error("failed to connect to mysql server")
        return nil
    end
    return db
end

local function acquire_mysql()
    local db
    if #pool.idle > 0 then
        db = table.remove(pool.idle)
    elseif pool.size < pool.max_size then
        db = connect_mysql()
        if db then
            pool.size = pool.size + 1
        end
    end
    if db then
        table.insert(pool.busy, db)
    end
    return db
end

local function release_db(db)
    for i, v in ipairs(pool.busy) do
        if v == db then
            table.remove(pool.busy, i)
            table.insert(pool.idle, db)
            return
        end
    end
    release_mysql(db)
end

local function mysql_query(db, sql)
    local res = db:query(sql)
    if not res then
        ERROR("[mysql]：查询sql语句 [ " .. sql .. " ]失败")
        return nil
    end
    return res
end

local function mysql_execute(db, sql, ...)
    local res, err = db:execute(sql, ...)
    if not res then
        ERROR("[mysql]：执行sql语句 [ " .. sql .. " ]失败: " .. err)
        return nil
    end
    return res
end

s.resp.query = function(source, sql)
    local db = acquire_mysql()

    if not db then
        ERROR("[mysql]：数据库获取失败")
        return nil
    end
    ERROR("query: " .. sql)
    local res = mysql_query(db, sql)
    release_db(db)
    return res
end

s.resp.execute = function(source, sql, ...)
	local s = {...} 
	ERROR(s[1])
    local db = acquire_mysql()
    if not db then
        ERROR("[mysql]：数据库获取失败")
        return nil
    end
    ERROR("execute: " .. sql)
    local res = mysql_execute(db, sql, ...)
    release_db(db)
    return res
end


function s.init() 
    create_pool()
end

s.start(...)
