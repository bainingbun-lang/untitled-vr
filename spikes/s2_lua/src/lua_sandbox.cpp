#include "lua_sandbox.h"

#include <godot_cpp/core/class_db.hpp>

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

#include <cstdlib>
#include <cstring>

using namespace godot;

namespace {

const char *const ERR_INSTRUCTION = "instruction limit exceeded";

void open_safe_libs(lua_State *L) {
	luaL_requiref(L, LUA_GNAME, luaopen_base, 1);
	lua_pop(L, 1);
	luaL_requiref(L, LUA_TABLIBNAME, luaopen_table, 1);
	lua_pop(L, 1);
	luaL_requiref(L, LUA_STRLIBNAME, luaopen_string, 1);
	lua_pop(L, 1);
	luaL_requiref(L, LUA_MATHLIBNAME, luaopen_math, 1);
	lua_pop(L, 1);
	luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);
	lua_pop(L, 1);
	luaL_requiref(L, LUA_COLIBNAME, luaopen_coroutine, 1);
	lua_pop(L, 1);

	// No io, os, package, debug or file loading in the sandbox.
	lua_pushnil(L);
	lua_setglobal(L, "dofile");
	lua_pushnil(L);
	lua_setglobal(L, "loadfile");
	lua_pushnil(L);
	lua_setglobal(L, "package");
}

String lua_error_string(lua_State *L) {
	size_t len = 0;
	const char *msg = lua_tolstring(L, -1, &len);
	if (msg == nullptr) {
		return String("unknown Lua error");
	}
	return String::utf8(msg, (int)len);
}

} // namespace

void LuaSandbox::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load", "source"), &LuaSandbox::load);
	ClassDB::bind_method(D_METHOD("call", "fn_name", "args"), &LuaSandbox::call);
	ClassDB::bind_method(D_METHOD("register_host", "name", "callable"), &LuaSandbox::register_host);
	ClassDB::bind_method(D_METHOD("reset"), &LuaSandbox::reset);
	ClassDB::bind_method(D_METHOD("set_memory_limit", "bytes"), &LuaSandbox::set_memory_limit);
	ClassDB::bind_method(D_METHOD("get_memory_limit"), &LuaSandbox::get_memory_limit);
	ClassDB::bind_method(D_METHOD("get_memory_used"), &LuaSandbox::get_memory_used);
	ClassDB::bind_method(D_METHOD("get_memory_peak"), &LuaSandbox::get_memory_peak);
	ClassDB::bind_method(D_METHOD("set_instruction_limit", "instructions"), &LuaSandbox::set_instruction_limit);
	ClassDB::bind_method(D_METHOD("get_instruction_limit"), &LuaSandbox::get_instruction_limit);
	ClassDB::bind_method(D_METHOD("get_last_error"), &LuaSandbox::get_last_error);
	ClassDB::bind_method(D_METHOD("get_last_error_kind"), &LuaSandbox::get_last_error_kind);
}

LuaSandbox::~LuaSandbox() {
	reset();
}

void *LuaSandbox::l_alloc(void *p_ud, void *p_ptr, size_t p_osize, size_t p_nsize) {
	LuaSandbox *self = static_cast<LuaSandbox *>(p_ud);
	if (self == nullptr) {
		return nullptr;
	}
	if (p_nsize == 0) {
		if (p_ptr != nullptr) {
			self->mem_used = (self->mem_used >= p_osize) ? self->mem_used - p_osize : 0;
			::free(p_ptr);
		}
		return nullptr;
	}

	size_t base = self->mem_used;
	if (p_ptr != nullptr) {
		// When p_ptr != nullptr, p_osize is the real size of the block.
		base = (self->mem_used >= p_osize) ? self->mem_used - p_osize : 0;
	}
	// When p_ptr == nullptr, p_osize is a Lua type tag, not a size.
	if (self->mem_limit > 0 && base + p_nsize > self->mem_limit) {
		return nullptr;
	}
	void *block = realloc(p_ptr, p_nsize);
	if (block == nullptr) {
		return nullptr;
	}
	self->mem_used = base + p_nsize;
	if (self->mem_used > self->mem_peak) {
		self->mem_peak = self->mem_used;
	}
	return block;
}

LuaSandbox *LuaSandbox::from_state(lua_State *p_state) {
	void *ud = nullptr;
	lua_getallocf(p_state, &ud);
	return static_cast<LuaSandbox *>(ud);
}

void LuaSandbox::instruction_hook(lua_State *p_state, lua_Debug *p_ar) {
	(void)p_ar;
	LuaSandbox *self = from_state(p_state);
	if (self == nullptr) {
		return;
	}
	self->instr_count += self->hook_step;
	if (self->instr_limit > 0 && self->instr_count > self->instr_limit) {
		lua_pushstring(p_state, ERR_INSTRUCTION);
		lua_error(p_state);
	}
}

int LuaSandbox::host_dispatch(lua_State *p_state) {
	LuaSandbox *self = from_state(p_state);
	if (self == nullptr) {
		return luaL_error(p_state, "sandbox: invalid state");
	}
	size_t name_len = 0;
	const char *name = lua_tolstring(p_state, lua_upvalueindex(1), &name_len);
	if (name == nullptr) {
		return luaL_error(p_state, "sandbox: invalid host name");
	}
	auto it = self->hosts.find(std::string(name, name_len));
	if (it == self->hosts.end()) {
		return luaL_error(p_state, "sandbox: unknown host function '%s'", name);
	}
	if (!it->second.is_valid()) {
		lua_pushnil(p_state);
		return 1;
	}
	int nargs = lua_gettop(p_state);
	Array args;
	for (int i = 1; i <= nargs; i++) {
		args.push_back(self->lua_to_variant(i, 0));
	}
	Variant result = it->second.callv(args);
	self->push_variant(result, 0);
	return 1;
}

int LuaSandbox::callable_dispatch(lua_State *p_state) {
	LuaSandbox *self = from_state(p_state);
	if (self == nullptr) {
		return luaL_error(p_state, "sandbox: invalid state");
	}
	int id = (int)lua_tointeger(p_state, lua_upvalueindex(1));
	auto it = self->callable_refs.find(id);
	if (it == self->callable_refs.end() || !it->second.is_valid()) {
		lua_pushnil(p_state);
		return 1;
	}
	int nargs = lua_gettop(p_state);
	Array args;
	for (int i = 1; i <= nargs; i++) {
		args.push_back(self->lua_to_variant(i, 0));
	}
	Variant result = it->second.callv(args);
	self->push_variant(result, 0);
	return 1;
}

void LuaSandbox::ensure_state() {
	if (state != nullptr) {
		return;
	}
	state = lua_newstate(&LuaSandbox::l_alloc, this);
	if (state == nullptr) {
		last_error = "failed to create Lua state";
		last_error_kind = "memory_limit";
		return;
	}
	open_safe_libs(state);
	for (const auto &entry : hosts) {
		install_host(entry.first);
	}
}

void LuaSandbox::install_host(const std::string &p_name) {
	lua_pushlstring(state, p_name.data(), p_name.size());
	lua_pushcclosure(state, &LuaSandbox::host_dispatch, 1);
	lua_setglobal(state, p_name.c_str());
}

void LuaSandbox::register_host(const String &p_name, const Callable &p_callable) {
	std::string name = p_name.utf8().get_data();
	hosts[name] = p_callable;
	if (state != nullptr) {
		install_host(name);
	}
}

void LuaSandbox::reset() {
	if (state != nullptr) {
		lua_close(state);
		state = nullptr;
	}
	callable_refs.clear();
	mem_used = 0;
	mem_peak = 0;
	instr_count = 0;
}

int LuaSandbox::guarded_pcall(int p_nargs, int p_nresults) {
	instr_count = 0;
	if (instr_limit > 0) {
		lua_sethook(state, &LuaSandbox::instruction_hook, LUA_MASKCOUNT, hook_step);
	}
	int status = lua_pcall(state, p_nargs, p_nresults, 0);
	lua_sethook(state, nullptr, 0, 0);
	return status;
}

Dictionary LuaSandbox::make_error(int p_status, const String &p_message) {
	String kind = "runtime";
	if (p_status == LUA_ERRMEM) {
		kind = "memory_limit";
	} else if (p_status == LUA_ERRSYNTAX) {
		kind = "syntax";
	} else if (p_message.contains(ERR_INSTRUCTION)) {
		kind = "instruction_limit";
	}
	last_error = p_message;
	last_error_kind = kind;
	Dictionary error;
	error["kind"] = kind;
	error["message"] = p_message;
	return error;
}

Variant LuaSandbox::load(const String &p_source) {
	ensure_state();
	if (state == nullptr) {
		Dictionary error;
		error["kind"] = last_error_kind;
		error["message"] = last_error;
		return error;
	}

	CharString chunk = p_source.utf8();
	int status = luaL_loadbufferx(state, chunk.get_data(), (size_t)chunk.length(), "=mod", "t");
	if (status != LUA_OK) {
		String message = lua_error_string(state);
		lua_pop(state, 1);
		return make_error(status, message);
	}

	status = guarded_pcall(0, 0);
	if (status != LUA_OK) {
		String message = lua_error_string(state);
		lua_pop(state, 1);
		return make_error(status, message);
	}

	last_error = "";
	last_error_kind = "";
	return Variant(true);
}

Variant LuaSandbox::call(const String &p_fn_name, const Array &p_args) {
	if (state == nullptr) {
		return make_error(LUA_ERRRUN, "no chunk loaded");
	}

	CharString name = p_fn_name.utf8();
	lua_getglobal(state, name.get_data());
	if (!lua_isfunction(state, -1)) {
		lua_pop(state, 1);
		return make_error(LUA_ERRRUN, String("global '") + p_fn_name + "' is not a function");
	}

	int nargs = p_args.size();
	for (int i = 0; i < nargs; i++) {
		push_variant(p_args[i], 0);
	}

	int status = guarded_pcall(nargs, 1);
	if (status != LUA_OK) {
		String message = lua_error_string(state);
		lua_pop(state, 1);
		return make_error(status, message);
	}

	Variant result = lua_to_variant(-1, 0);
	lua_pop(state, 1);
	last_error = "";
	last_error_kind = "";
	return result;
}

Variant LuaSandbox::lua_to_variant(int p_index, int p_depth) {
	if (p_depth > 32) {
		return Variant();
	}
	int index = lua_absindex(state, p_index);
	switch (lua_type(state, index)) {
		case LUA_TNIL:
			return Variant();
		case LUA_TBOOLEAN:
			return Variant((bool)(lua_toboolean(state, index) != 0));
		case LUA_TNUMBER:
			if (lua_isinteger(state, index)) {
				return Variant((int64_t)lua_tointeger(state, index));
			}
			return Variant((double)lua_tonumber(state, index));
		case LUA_TSTRING: {
			size_t len = 0;
			const char *str = lua_tolstring(state, index, &len);
			return Variant(String::utf8(str, (int)len));
		}
		case LUA_TTABLE: {
			bool array_like = true;
			int64_t count = 0;
			int64_t max_index = 0;
			lua_pushnil(state);
			while (lua_next(state, index) != 0) {
				if (lua_type(state, -2) == LUA_TNUMBER && lua_isinteger(state, -2)) {
					int64_t key = (int64_t)lua_tointeger(state, -2);
					if (key >= 1) {
						count++;
						if (key > max_index) {
							max_index = key;
						}
					} else {
						array_like = false;
					}
				} else {
					array_like = false;
				}
				lua_pop(state, 1);
			}

			if (array_like && max_index == count) {
				Array array;
				array.resize((int)count);
				lua_pushnil(state);
				while (lua_next(state, index) != 0) {
					int64_t key = (int64_t)lua_tointeger(state, -2);
					array[key - 1] = lua_to_variant(-1, p_depth + 1);
					lua_pop(state, 1);
				}
				return array;
			}

			Dictionary dict;
			lua_pushnil(state);
			while (lua_next(state, index) != 0) {
				Variant key = lua_to_variant(-2, p_depth + 1);
				if (key.get_type() != Variant::ARRAY && key.get_type() != Variant::DICTIONARY) {
					dict[key] = lua_to_variant(-1, p_depth + 1);
				}
				lua_pop(state, 1);
			}
			return dict;
		}
		default:
			return Variant();
	}
}

void LuaSandbox::push_callable(const Callable &p_callable) {
	int id = next_callable_id++;
	callable_refs[id] = p_callable;
	lua_pushinteger(state, (lua_Integer)id);
	lua_pushcclosure(state, &LuaSandbox::callable_dispatch, 1);
}

void LuaSandbox::push_variant(const Variant &p_value, int p_depth) {
	if (state == nullptr || p_depth > 32) {
		if (state != nullptr) {
			lua_pushnil(state);
		}
		return;
	}
	switch (p_value.get_type()) {
		case Variant::NIL:
			lua_pushnil(state);
			break;
		case Variant::BOOL:
			lua_pushboolean(state, (bool)p_value ? 1 : 0);
			break;
		case Variant::INT:
			lua_pushinteger(state, (lua_Integer)(int64_t)p_value);
			break;
		case Variant::FLOAT:
			lua_pushnumber(state, (lua_Number)(double)p_value);
			break;
		case Variant::STRING:
		case Variant::STRING_NAME: {
			CharString utf8 = String(p_value).utf8();
			lua_pushlstring(state, utf8.get_data(), (size_t)utf8.length());
			break;
		}
		case Variant::ARRAY: {
			Array array = p_value;
			lua_createtable(state, array.size(), 0);
			for (int i = 0; i < array.size(); i++) {
				push_variant(array[i], p_depth + 1);
				lua_rawseti(state, -2, i + 1);
			}
			break;
		}
		case Variant::DICTIONARY: {
			Dictionary dict = p_value;
			Array keys = dict.keys();
			lua_createtable(state, 0, keys.size());
			for (int i = 0; i < keys.size(); i++) {
				push_variant(keys[i], p_depth + 1);
				push_variant(dict[keys[i]], p_depth + 1);
				lua_settable(state, -3);
			}
			break;
		}
		case Variant::CALLABLE:
			push_callable(p_value);
			break;
		default:
			lua_pushnil(state);
			break;
	}
}

void LuaSandbox::set_memory_limit(int64_t p_bytes) {
	mem_limit = p_bytes > 0 ? (size_t)p_bytes : 0;
}

int64_t LuaSandbox::get_memory_limit() const {
	return (int64_t)mem_limit;
}

int64_t LuaSandbox::get_memory_used() const {
	return (int64_t)mem_used;
}

int64_t LuaSandbox::get_memory_peak() const {
	return (int64_t)mem_peak;
}

void LuaSandbox::set_instruction_limit(int64_t p_instructions) {
	instr_limit = p_instructions > 0 ? p_instructions : 0;
	hook_step = (int)(instr_limit > 0 && instr_limit < 10000 ? instr_limit : 10000);
	if (hook_step < 1) {
		hook_step = 1;
	}
}

int64_t LuaSandbox::get_instruction_limit() const {
	return instr_limit;
}

String LuaSandbox::get_last_error() const {
	return last_error;
}

String LuaSandbox::get_last_error_kind() const {
	return last_error_kind;
}
