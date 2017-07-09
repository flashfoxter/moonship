local util = require("moonship.util")
local httpc = require("moonship.http")
local log = require("moonship.log")
local url_parse, trim, path_sanitize, url_build
url_parse, trim, path_sanitize, url_build = util.url_parse, util.trim, util.path_sanitize, util.url_build
local loadcode
loadcode = function(url)
  local req = {
    url = url,
    method = "GET",
    capture_url = "/__libpublic",
    headers = { }
  }
  local res, err = httpc.request(req)
  if not (err) then
    return res
  end
  return {
    code = 0,
    body = err
  }
end
local resolve_remote
resolve_remote = function(modname)
  local parsed = url_parse(modname)
  local file
  parsed.basepath, file = string.match(parsed.path, "^(.*)/([^/]*)$")
  parsed.file = trim(file, "/*") or ""
  if not (parsed.basepath) then
    parsed.basepath = "/"
  end
  return parsed
end
local resolve_github
resolve_github = function(modname)
  modname = modname:gsub("github%.com/", "https://raw.githubusercontent.com/")
  local parsed = resolve_remote(modname)
  local user, repo, blobortree, branch, rest = string.match(parsed.basepath, "(/[^/]+)(/[^/]+)(/[^/]+)(/[^/]+)(.*)")
  parsed.basepath = path_sanitize(tostring(user) .. tostring(repo) .. tostring(branch) .. tostring(rest))
  parsed.path = tostring(parsed.basepath) .. "/" .. tostring(parsed.file)
  return parsed
end
local resolve
resolve = function(modname)
  local originalName = tostring(modname):gsub("%.moon$", "")
  local rst = { }
  if modname:find("http") == 1 then
    rst = resolve_remote(modname)
  end
  if modname:find("github%.com/") == 1 then
    rst = resolve_github(modname)
  end
  local remotebase = _G["_remotebase"]
  if remotebase ~= nil and rst.path == nil then
    local remotemodname = tostring(remotebase) .. "/" .. tostring(modname)
    if remotemodname:find("http") == 1 then
      rst = resolve_remote(remotemodname)
    end
    rst._remotebase = remotebase
  end
  if not (rst.path) then
    return {
      path = modname
    }
  end
  rst.file = rst.file:gsub("%.moon$", ""):gsub('%.', "/") .. ".moon"
  rst.path = rst.path:gsub("%.moon$", ""):gsub('%.', "/") .. ".moon"
  local oldpath = rst.path
  rst.path = path_sanitize(rst.basepath)
  rst.basepath = url_build(rst, false)
  rst.path = oldpath
  rst.codeloader = loadcode
  if not (originalName:find("%.")) then
    rst._remotebase = trim(rst.basepath, "/")
  end
  return rst
end
return {
  resolve = resolve,
  resolve_github = resolve_github,
  resolve_remote = resolve_remote,
  loadcode = loadcode
}