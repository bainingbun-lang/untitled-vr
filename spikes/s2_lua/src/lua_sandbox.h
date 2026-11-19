#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <map>
#include <string>

struct lua_State;
struct lua_Debug;

namespace godot {

class LuaSandbox : public RefCounted {
	GDCLASS(LuaSandbox, RefCounted)

	// C++ object state.
	lua_State *state = nullptr;
	size_t mem_used = 0;
	size_t mem_peak = 0;
	size_t mem_limit = 16u * 1024u * 1024u;
	long long instr_limit = 1000000;
	long long instr_count = 0;
	int hook_step = 10000;
	std::map<std::string, Callable> hosts;
	std::map<int, Callable> callable_refs;
	int next_callable_id = 1;
	String last_error;
	String last_error_kind;

protected:
	static void _bind_methods();

public:
	LuaSandbox() = default;
	~LuaSandbox() override;

	Variant load(const String &p_source);
	Variant call(const String &p_fn_name, const Array &p_args);
	void register_host(const String &p_name, const Callable &p_callable);
	void reset();

	void set_memory_limit(int64_t p_bytes);
	int64_t get_memory_limit() const;
	int64_t get_memory_used() const;
	int64_t get_memory_peak() const;
	void set_instruction_limit(int64_t p_instructions);
	int64_t get_instruction_limit() const;
	String get_last_error() const;
	String get_last_error_kind() const;

private:
	void ensure_state();
	void install_host(const std::string &p_name);
	int guarded_pcall(int p_nargs, int p_nresults);
	Dictionary make_error(int p_status, const String &p_message);
	Variant lua_to_variant(int p_index, int p_depth);
	void push_variant(const Variant &p_value, int p_depth);
	void push_callable(const Callable &p_callable);

	static void *l_alloc(void *p_ud, void *p_ptr, size_t p_osize, size_t p_nsize);
	static void instruction_hook(lua_State *p_state, lua_Debug *p_ar);
	static int host_dispatch(lua_State *p_state);
	static int callable_dispatch(lua_State *p_state);
	static LuaSandbox *from_state(lua_State *p_state);
};

} // namespace godot
