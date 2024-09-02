local skynet = require "skynet"
local runconfig = require "runconfig"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"

skynet.start(function()
    -- 服务类型, 第二参数之后传给 start(...)
    
    -- 初始化
    local mynode = skynet.getenv("node")
    local nodecfg = runconfig[mynode]

    -- 节点管理
    local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0) 
    skynet.name("nodemgr", nodemgr) 

    -- 集群
    cluster.reload(runconfig.cluster) 
    cluster.open(mynode) 

    -- 数据库连接池
    local mysql = skynet.newservice("mysql", "mysql", 0)
    skynet.name("mysql", mysql)
    -- 消息分发服务
    local msgserver = skynet.newservice("msgserver", "msgserver", 0)
    skynet.name("msgserver", msgserver)

    -- gate 
    for i, v in pairs(nodecfg.gateway) do 
        local srv = skynet.newservice("gateway", "gateway", i) 
        skynet.name("gateway" .. i, srv)
    end 

    -- login 
    for i, v in pairs(nodecfg.login or {}) do 
        local srv = skynet.newservice("login", "login", i) 
        skynet.name("login" .. i, srv)
    end 

    -- agentmgr
    local anode = runconfig.agentmgr.node 
    if mynode == anode then 
        local srv = skynet.newservice("agentmgr", "agentmgr", 0)
        skynet.name("agentmgr", srv) 
    else 
        local proxy = cluster.proxy(anode, "agentmgr") 
        skynet.name("agentmgr", proxy)
    end 

    -- scene (sid -> sceneid)
    -- 这里固定数量scene服务，可以仿造agent动态开scene
    for _, sid in pairs(runconfig.scene[mynode] or {}) do 
        local srv = skynet.newservice("scene", "scene", sid)
        skynet.name("scene" .. sid, srv)
    end

    for _, sid in pairs(runconfig.admin[mynode] or {}) do 
        local srv = skynet.newservice("admin", "admin", sid)
        skynet.name("admin", srv)
    end


    skynet.exit()
end)
