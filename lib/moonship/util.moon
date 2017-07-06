
url              = require "moonship.url"
cjson_safe       = require "cjson.safe"
log              = require "moonship.log"

import concat, insert, sort from table

-- our utils lib, nothing here should depend on ngx
-- for ngx stuff, put it inside ngin.lua file
local *

url_unescape = (str) ->
  str = str\gsub('+', ' ')
  str\gsub("%%(%x%x)", (c) -> return string.char(tonumber(c, 16)))

-- https://stackoverflow.com/questions/2322764/what-characters-must-be-escaped-in-an-http-query-string
url_escape = (str) -> string.gsub(str, "([ /?:@~!$&'()*+,;=%[%]%c])", (c) -> string.format("%%%02X", string.byte(c)))

url_parse = (myurl) -> url.parse(myurl)

url_default_port = (scheme) -> url.default_port(scheme)

-- {
--     [path] = "/test"
--     [scheme] = "http"
--     [host] = "localhost.com"
--     [port] = "8080"
--     [fragment] = "!hash_bang"
--     [query] = "hello=world"
-- }
url_build = (parts, includeQuery=true) ->
  out = parts.path or ""
  if includeQuery
    out ..= "?" .. parts.query if parts.query
    out ..= "#" .. parts.fragment if parts.fragment

  if host = parts.host
    host = "//" .. host
    host ..= ":" .. parts.port if parts.port
    host = parts.scheme .. ":" .. host if parts.scheme and parts.scheme != ""
    out = "/" .. out if parts.path and out\sub(1,1) != "/"
    out = host .. out

  out


trim = (str, regex="%s*") ->
  str = tostring str

  if #str > 200
    str\gsub("^#{regex}", "")\reverse()\gsub("^#{regex}", "")\reverse()
  else
    str\match "^#{regex}(.-)#{regex}$"

path_sanitize = (str) ->
  str = tostring str
  -- path should not have double quote, single quote, period
  -- purposely left casing alone because paths are case-sensitive
  -- finally, remove double period and make single forward slash
  str\gsub("[^a-zA-Z0-9.-_/]", "")\gsub("%.%.+", "")\gsub("//+", "/")

slugify = (str) ->
  str = tostring str
  (str\gsub("[%s_]+", "-")\gsub("[^%w%-]+", "")\gsub("-+", "-"))\lower!

string_split = url.string_split

json_encodable = (obj, seen={}) ->
  switch type obj
    when "table"
      unless seen[obj]
        seen[obj] = true
        { k, json_encodable(v) for k,v in pairs(obj) when type(k) == "string" or type(k) == "number" }
    when "function", "userdata", "thread"
      nil
    else
      obj

from_json = (obj) -> cjson_safe.decode obj

to_json = (obj) -> cjson_safe.encode (json_encodable obj)

query_string_encode = (t, sep="&", quote="", seen={}) ->
  query = {}
  keys = {}
  for k in pairs(t) do keys[#keys+1] = tostring(k)
  sort(keys)

  for _,k in ipairs(keys) do
    v = t[k]

    switch type v
      when "table"
        unless seen[v]
          seen[v] = true
          tv = query_string_encode(v, sep, quote, seen)
          v = tv
      when "function", "userdata", "thread"
        nil
      else
        v = url_escape(tostring(v))

    k = url_escape(tostring(k))

    if v ~= "" then
      query[#query+1] = string.format('%s=%s', k, quote .. v .. quote)
    else
      query[#query+1] = name

  concat(query, sep)

resolveGithubRaw = (modname) ->
  capturePath = "https://raw.githubusercontent.com/"
  if string.find(modname, "github.com/")
    user, repo, branch, pathx, query = string.match(modname, "github%.com/([^/]+)(/[^/]+)/tree(/[^/]+)(/[^?#]*)(.*)")
    path, file = string.match(pathx, "^(.*/)([^/]*)$")
    base = string.format("%s%s%s%s%s", capturePath, user, repo, branch, path)

    -- convert period to folder before return
    return base, string.gsub(string.gsub(file, "%.moon$", ""), '%.', "/") .. ".moon", query

  __ghrawbase, string.gsub(string.gsub(modname, "%.moon$", ""), '%.', "/") .. ".moon", ""

clone = (src, dest={}) ->
  for k, v in pairs(src) do dest[k] = v
  dest

applyDefaults = (opts, defOpts) ->
  for k, v in pairs(defOpts) do
    opts[k] = v unless opts[k]

  opts

{ :url_escape, :url_unescape, :url_parse, :url_build, :url_default_port,
  :trim, :path_sanitize, :slugify, :string_split, :table_sort_keys,
  :json_encodable, :from_json, :to_json, :clone,
  :query_string_encode, :resolveGithubRaw, :applyDefaults
}