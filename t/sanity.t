# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * ( 3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    resolver 192.168.101.11;
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();

run_tests();

__DATA__

=== TEST 1: basic
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local http = require "resty.http"
            local hc = http:new()

            local ok, code, headers, status, body  = hc:request {
                url = "http://www.qunar.com/",
                -- proxy = "http://127.0.0.1:8888",
                -- timeout = 3000,
                -- headers = { UserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11"}
            }

            ngx.say(ok)
            ngx.say(code)
            ngx.say(status)
        ';
    }
--- request
GET /t
--- response_body
1
200
HTTP/1.1 200 OK
--- no_error_log
[error]
