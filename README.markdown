Name
====

lua-resty-http - Lua http client driver for the ngx_lua based on the cosocket API

Status
======

This library is considered experimental and still under active development.

The API is still in flux and may change without notice.

Description
===========

This Lua library is a http client driver for the ngx_lua nginx module:

http://wiki.nginx.org/HttpLuaModule

This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Note that at least [ngx_lua 0.5.0rc3](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx_openresty 1.0.11.3](http://openresty.org/#Download) is required.

Synopsis
========

    lua_package_path "/path/to/lua-resty-http/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
                local http = require "resty.http"
                local hc = http:new()

                local ok, code, headers, status, body  = hc:request {
                    url = "http://www.qunar.com/",
                    --- proxy = "http://127.0.0.1:8888",
                    --- timeout = 3000,
                    method = "POST", -- POST or GET
                    -- add post content-type and cookie
                    headers = { Cookie = "ABCDEFG", ["Content-Type"] = "application/x-www-form-urlencoded" },
                    body = "uid=1234567890",
                }

                ngx.say(ok)
                ngx.say(code)
                ngx.say(body)
            ';
        }
    }

TODO
====

* implement the redirect supported
* implement the chunked
* implement the keepalive

Authors
=======

"liseen" <liseen.wan@gmail.com>

"wendal" <wendal1985@gmail.com>

"wangchll" <wangchong1985@gmail.com>

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2012, by Zhang "agentzh" Yichun (章亦春) <agentzh@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See Also
========
* the ngx_lua module: http://wiki.nginx.org/HttpLuaModule
* the memcached wired protocol specification: http://code.sixapart.com/svn/memcached/trunk/server/doc/protocol.txt
* the [lua-resty-redis](https://github.com/agentzh/lua-resty-redis) library.
* the [lua-resty-mysql](https://github.com/agentzh/lua-resty-mysql) library.

