#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <wasmtime.h>

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace godot {

class WasmSandbox : public RefCounted {
	GDCLASS(WasmSandbox, RefCounted)

	struct HostBinding {
		WasmSandbox *self = nullptr;
		std::string name;
		std::vector<uint8_t> result_kinds;
	};

	wasm_engine_t *engine = nullptr;
	wasmtime_module_t *module = nullptr;
	wasmtime_store_t *store = nullptr;
	wasmtime_linker_t *linker = nullptr;
	wasmtime_context_t *ctx = nullptr;
	wasmtime_instance_t instance = {};
	bool have_instance = false;

	std::vector<uint8_t> module_bytes;
	size_t memory_limit = 64u * 1024u * 1024u;
	uint64_t fuel_limit = 10000000;
	std::map<std::string, Callable> hosts;

	String last_error;
	String last_error_kind;

protected:
	static void _bind_methods();

public:
	WasmSandbox() = default;
	~WasmSandbox() override;

	Variant load(const PackedByteArray &p_bytes);
	Variant call(const String &p_fn_name, const Array &p_args);
	void register_host(const String &p_name, const Callable &p_callable);
	void reset();

	void set_memory_limit(int64_t p_bytes);
	int64_t get_memory_limit() const;
	void set_fuel_limit(int64_t p_fuel);
	int64_t get_fuel_limit() const;
	String get_last_error() const;
	String get_last_error_kind() const;
	bool is_loaded() const;

private:
	void ensure_engine();
	void reset_instance();
	Variant instantiate();
	Variant fail(const String &p_kind, const String &p_message);
	void clear_error();
	Dictionary make_error(const String &p_kind, const String &p_message) const;

	static String take_error(wasmtime_error_t *p_error);
	static String take_trap(wasm_trap_t *p_trap, bool &r_out_of_fuel);
	static Variant val_to_variant(const wasmtime_val_t &p_val);
	static bool variant_to_val(const Variant &p_value, uint8_t p_kind, wasmtime_val_t &r_out);
	static wasm_trap_t *host_callback(void *p_env, wasmtime_caller_t *p_caller,
			const wasmtime_val_t *p_args, size_t p_nargs,
			wasmtime_val_t *p_results, size_t p_nresults);
	static void host_binding_finalizer(void *p_env);
};

} // namespace godot
