module("resty.http", package.seeall)

_VERSION = '0.2'

-- constants
-- connection timeout in seconds
local TIMEOUT = 60
-- default port for document retrieval
local PORT = 80
-- user agent field sent in request
local USERAGENT = 'resty.http/' .. _VERSION

-- default url parts
local default = {
    host = "",
    port = PORT,
    path ="/",
    scheme = "http"
}


-- global variables
local url = require("resty.url")

local mt = { __index = resty.http }

local tcp = ngx.socket.tcp


local function adjusturi(reqt)
    local u = reqt
    -- if there is a proxy, we need the full url. otherwise, just a part.
    if not reqt.proxy and not PROXY then
        u = {
           path = reqt.path,
           params = reqt.params,
           query = reqt.query,
           fragment = reqt.fragment
        }
    end
    return url.build(u)
end


local function adjustheaders(reqt)
    -- default headers
    local lower = {
        ["user-agent"] = USERAGENT,
        ["host"] = reqt.host,
        ["connection"] = "close, TE",
        ["te"] = "trailers"
    }
    -- if we have authentication information, pass it along
    if reqt.user and reqt.password then
        lower["authorization"] = 
            "Basic " ..  (mime.b64(reqt.user .. ":" .. reqt.password))
    end
    -- override with user headers
    for i,v in pairs(reqt.headers or lower) do
        lower[string.lower(i)] = v
    end
    return lower
end


local function adjustproxy(reqt)
    local proxy = reqt.proxy or PROXY
    if proxy then
        proxy = url.parse(proxy)
        return proxy.host, proxy.port or 3128
    else
        return reqt.host, reqt.port
    end
end


local function adjustrequest(reqt)
    -- parse url if provided
    local nreqt = reqt.url and url.parse(reqt.url, default) or {}
    -- explicit components override url
    for i,v in pairs(reqt) do nreqt[i] = v end

    if nreqt.port == "" then nreqt.port = 80 end

    -- compute uri if user hasn't overriden
    nreqt.uri = reqt.uri or adjusturi(nreqt)
    -- ajust host and port if there is a proxy
    nreqt.host, nreqt.port = adjustproxy(nreqt)
    -- adjust headers in request
    nreqt.headers = adjustheaders(nreqt)

    nreqt.timeout = reqt.timeout or TIMEOUT * 1000;

    return nreqt
end


local function receivestatusline(sock)
    local status_reader = sock:receiveuntil("\r\n")

    local data, err, partial = status_reader()
    if not data then
        return nil, "read status line failed " .. err
    end

    local t1, t2, code = string.find(data, "HTTP/%d*%.%d* (%d%d%d)")

    return tonumber(code), data
end


local function receiveheaders(sock, headers)
    local line, name, value, err, tmp1, tmp2
    headers = headers or {}
    -- get first line
    line, err = sock:receive()
    if err then return nil, err end
    -- headers go until a blank line is found
    while line ~= "" do
        -- get field-name and value
        tmp1, tmp2, name, value = string.find(line, "^(.-):%s*(.*)")
        if not (name and value) then return nil, "malformed reponse headers" end
        name = string.lower(name)
        -- get next line (value might be folded)
        line, err  = sock:receive()
        if err then return nil, err end
        -- unfold any folded values
        while string.find(line, "^%s") do
            value = value .. line
            line = sock:receive()
            if err then return nil, err end
        end
        -- save pair in table
        if headers[name] then headers[name] = headers[name] .. ", " .. value
        else headers[name] = value end
    end
    return headers
end

local function receivebody(sock, headers, nreqt)
    local t = headers["transfer-encoding"] -- shortcut
    local body = ''
    local callback = nreqt.body_callback
    if not callback then
        local function bc(event_type, data)
            if 'body' == event_type then
                body = body .. data
            end
        end
    end
    if t and t ~= "identity" then
        -- chunked
            while true do
                local chunk_header = sock:receiveuntil("\r\n")
                local data, err, partial = chunk_header()
                if not err then
                    if data == "0\r\n" then
                        return body
                    else
                        local data, err, partial = sock:receive(string.sub(data, 1, len(data) - 1))
                        if not err then
                            callback(data)
                        elseif err == "closed" then
                            callback(partial)
                            return body
                        else
                            return nil, err
                        end
                    end
                end
            end
    elseif headers["content-length"] ~= nil then
        -- content length
        local length = tonumber(headers["content-length"])
        local data, err, partial = sock:receive(length)
        if not err then
            callback(data)
        elseif err == "closed" then
            callback(partial)
            return body
        else
            return nil, err
        end
    else
        -- connection close
        local body = ''
        while true do
            local data, err, partial = sock:receive(nreqt.fetch_size or 16*1024)
            if not err then
                callback(data)
            elseif err == "closed" then
                callback(partial)
                return body
            else
                return nil, err
            end
        end
    end
end


local function shouldredirect(reqt, code, headers)
    return headers.location and
           string.gsub(headers.location, "%s", "") ~= "" and
           (reqt.redirect ~= false) and
           (code == 301 or code == 302) and
           (not reqt.method or reqt.method == "GET" or reqt.method == "HEAD")
           and (not reqt.nredirects or reqt.nredirects < 5)
end


local function shouldreceivebody(reqt, code)
    if reqt.method == "HEAD" then return nil end
    if code == 204 or code == 304 then return nil end
    if code >= 100 and code < 200 then return nil end
    return 1
end


function new(self)
    return setmetatable({}, mt)
end


function request(self, reqt)
    local code, headers, status, body, bytes, ok, err

    local nreqt = adjustrequest(reqt)

    local sock = tcp()
    if not sock then
        return nil, "create sock failed"
    end

    sock:settimeout(nreqt.timeout)

    -- connect
    ok, err = sock:connect(nreqt.host, nreqt.port)
    if not ok then
        return nil, "sock connected failed " .. err
    end

    -- send request line and headers
    local reqline = string.format("%s %s HTTP/1.0\r\n", nreqt.method or "GET", nreqt.uri)

    local h = "\r\n"
    for i, v in pairs(nreqt.headers) do
        h = i .. ": " .. v .. "\r\n" .. h
    end
    bytes, err = sock:send(reqline .. h)
    if not bytes then
        sock:close()
        return nil, err
    end

	-- send body
	if nreqt.body then
	    bytes, err = sock:send(body)
		if not bytes then
			sock:close()
			return nil, "send body failed" .. err	
		end
	end

    -- receive status line
    code, status = receivestatusline(sock)
    if not code then
        sock:close()
        return nil, "read status line failed " .. status
    end

    -- ignore any 100-continue messages
    while code == 100 do
        headers, err = receiveheaders(sock, {})
        code, status = receivestatusline(sock)
    end
    
    -- notify code_callback
    if nreqt.code_callback then
        nreqt.code_callback(code)
    end

    -- receive headers
    headers, err = receiveheaders(sock, {})
    if not headers then
        sock:close()
        return nil, "read headers failed " .. err
    end

    -- notify header_callback
    if nreqt.header_callback then
        nreqt.header_callback(headers)
    end
    
    -- TODO rediret check

    -- receive body
    if shouldreceivebody(nreqt, code) then
        body, err = receivebody(sock, headers, nreqt)
        if not body then
            sock:close()
            return nil, "read body failed " .. err
        end
    end

    ok, err = sock:close()
    if not ok and err ~= 'closed' then
        return nil, "close sock failed " .. err
    end

    return 1, code, headers, status, body
end

function proxy_pass(self, reqt)
    local nreqt = {}
    for i,v in pairs(reqt) do nreqt[i] = v end
    if not nreqt.code_callback then
        nreqt.code_callback = function(code) 
            ngx.status = code
        end
    end
    
    if not nreqt.header_callback then
        nreqt.header_callback = function (headers)
            for i, v in pairs(headers) do
                ngx.header[i] = v
            end
        end
    end
    
    if not nreqt.body_callback then
        nreqt.body_callback = function (data)
            ngx.print(data)
        end
    end
    return request(self, nreqt)
end

-- to prevent use of casual module global variables
getmetatable(resty.http).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '
            .. debug.traceback())
end

