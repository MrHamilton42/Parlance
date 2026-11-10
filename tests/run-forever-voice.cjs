const fs = require('node:fs');
const path = require('node:path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const addon = path.join(__dirname, '..', 'ForeverVoice');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
try {
  for (const name of ['Sharing', 'Core', 'Editor']) {
    const source = fs.readFileSync(path.join(addon, name + '.lua'), 'utf8');
    luaparse.parse(source, { luaVersion: '5.1' });
    lua.lua_pushstring(L, to_luastring(source));
    lua.lua_setglobal(L, to_luastring('__' + name));
  }
  const test = fs.readFileSync(path.join(__dirname, 'forever-voice-tests.lua'), 'utf8');
  if (lauxlib.luaL_dostring(L, to_luastring(test)) !== lua.LUA_OK) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
} finally {
  lua.lua_close(L);
}
