#include "wasm_sandbox.h"

#include <godot_cpp/core/class_db.hpp>

#include <cstring>
#include <set>

using namespace godot;

namespace {

const char *const HOST_MODULE = "host";

String name_to_string(const wasm_name_t *p_name) {
	if (p_name == nullptr || p_name->data == nullptr) {
		return String();
	}
	return String::utf8(p_name->data, (int)p_name->size);
}

} // namespace

void WasmSandbox::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load", "bytes"), &WasmSandbox::load);
	ClassDB::bind_method(D_METHOD("call", "fn_name", "args"), &WasmSandbox::call);
	ClassDB::bind_method(D_METHOD("register_host", "name", "callable"), &WasmSandbox::register_host);
	ClassDB::bind_method(D_METHOD("reset"), &WasmSandbox::reset);
	ClassDB::bind_method(D_METHOD("set_memory_limit", "bytes"), &WasmSandbox::set_memory_limit);
	ClassDB::bind_method(D_METHOD("get_memory_limit"), &WasmSandbox::get_memory_limit);
	ClassDB::bind_method(D_METHOD("set_fuel_limit", "fuel"), &WasmSandbox::set_fuel_limit);
	ClassDB::bind_method(D_METHOD("get_fuel_limit"), &WasmSandbox::get_fuel_limit);
	ClassDB::bind_method(D_METHOD("get_last_error"), &WasmSandbox::get_last_error);
	ClassDB::bind_method(D_METHOD("get_last_error_kind"), &WasmSandbox::get_last_error_kind);
	ClassDB::bind_method(D_METHOD("is_loaded"), &WasmSandbox::is_loaded);
}

WasmSandbox::~WasmSandbox() {
	reset();
	if (engine != nullptr) {
		wasm_engine_delete(engine);
		engine = nullptr;
	}
}

String WasmSandbox::take_error(wasmtime_error_t *p_error) {
	if (p_error == nullptr) {
		return String();
	}
	wasm_message_t message;
	std::memset(&message, 0, sizeof(message));
	wasmtime_error_message(p_error, &message);
	String result = String::utf8(message.data, (int)message.size);
	wasm_byte_vec_delete(&message);
	wasmtime_error_delete(p_error);
	return result;
}

String WasmSandbox::take_trap(wasm_trap_t *p_trap, bool &r_out_of_fuel) {
	r_out_of_fuel = false;
	if (p_trap == nullptr) {
		return String();
	}
	wasm_message_t message;
	std::memset(&message, 0, sizeof(message));
	wasm_trap_message(p_trap, &message);
	String result = String::utf8(message.data, (int)message.size);
	wasm_byte_vec_delete(&message);

	wasmtime_trap_code_t code = 0;
	if (wasmtime_trap_code(p_trap, &code) && code == WASMTIME_TRAP_CODE_OUT_OF_FUEL) {
		r_out_of_fuel = true;
	}
	wasm_trap_delete(p_trap);
	return result;
}

Variant WasmSandbox::val_to_variant(const wasmtime_val_t &p_val) {
	switch (p_val.kind) {
		case WASMTIME_I32:
			return (int64_t)p_val.of.i32;
		case WASMTIME_I64:
			return (int64_t)p_val.of.i64;
		case WASMTIME_F32:
			return (double)p_val.of.f32;
		case WASMTIME_F64:
			return (double)p_val.of.f64;
		default:
			return Variant();
	}
}

bool WasmSandbox::variant_to_val(const Variant &p_value, uint8_t p_kind, wasmtime_val_t &r_out) {
	std::memset(&r_out, 0, sizeof(r_out));
	r_out.kind = p_kind;
	switch (p_kind) {
		case WASMTIME_I32: {
			if (p_value.get_type() != Variant::INT && p_value.get_type() != Variant::FLOAT && p_value.get_type() != Variant::BOOL) {
				return false;
			}
			r_out.of.i32 = (int32_t)(int64_t)p_value;
			return true;
		}
		case WASMTIME_I64: {
			if (p_value.get_type() != Variant::INT && p_value.get_type() != Variant::FLOAT && p_value.get_type() != Variant::BOOL) {
				return false;
			}
			r_out.of.i64 = (int64_t)p_value;
			return true;
		}
		case WASMTIME_F32: {
			if (p_value.get_type() != Variant::FLOAT && p_value.get_type() != Variant::INT) {
				return false;
			}
			r_out.of.f32 = (float)(double)p_value;
			return true;
		}
		case WASMTIME_F64: {
			if (p_value.get_type() != Variant::FLOAT && p_value.get_type() != Variant::INT) {
				return false;
			}
			r_out.of.f64 = (double)p_value;
			return true;
		}
		default:
			return false;
	}
}

void WasmSandbox::ensure_engine() {
	if (engine != nullptr) {
		return;
	}
	wasm_config_t *config = wasm_config_new();
	wasmtime_config_consume_fuel_set(config, true);
	engine = wasm_engine_new_with_config(config);
}

void WasmSandbox::reset_instance() {
	if (store != nullptr) {
		wasmtime_store_delete(store);
		store = nullptr;
	}
	if (linker != nullptr) {
		wasmtime_linker_delete(linker);
		linker = nullptr;
	}
	ctx = nullptr;
	instance = {};
	have_instance = false;
}

void WasmSandbox::reset() {
	reset_instance();
	if (module != nullptr) {
		wasmtime_module_delete(module);
		module = nullptr;
	}
	module_bytes.clear();
	clear_error();
}

void WasmSandbox::clear_error() {
	last_error = String();
	last_error_kind = String();
}

Dictionary WasmSandbox::make_error(const String &p_kind, const String &p_message) const {
	Dictionary error;
	error["kind"] = p_kind;
	error["message"] = p_message;
	return error;
}

Variant WasmSandbox::fail(const String &p_kind, const String &p_message) {
	last_error_kind = p_kind;
	last_error = p_message;
	return make_error(p_kind, p_message);
}

void WasmSandbox::host_binding_finalizer(void *p_env) {
	delete static_cast<HostBinding *>(p_env);
}

wasm_trap_t *WasmSandbox::host_callback(void *p_env, wasmtime_caller_t *p_caller,
		const wasmtime_val_t *p_args, size_t p_nargs,
		wasmtime_val_t *p_results, size_t p_nresults) {
	(void)p_caller;
	HostBinding *binding = static_cast<HostBinding *>(p_env);
	if (binding == nullptr || binding->self == nullptr) {
		return wasmtime_trap_new("sandbox: invalid host binding", 30);
	}
	WasmSandbox *self = binding->self;
	auto it = self->hosts.find(binding->name);
	if (it == self->hosts.end() || !it->second.is_valid()) {
		const char *msg = "sandbox: host function not available";
		self->last_error_kind = "host_error";
		self->last_error = msg;
		return wasmtime_trap_new(msg, std::strlen(msg));
	}

	Array args;
	for (size_t i = 0; i < p_nargs; i++) {
		args.push_back(val_to_variant(p_args[i]));
	}
	Variant result = it->second.callv(args);

	if (p_nresults == 0) {
		return nullptr;
	}
	Variant first = result;
	if (result.get_type() == Variant::ARRAY && p_nresults > 1) {
		Array result_array = result;
		for (size_t i = 0; i < p_nresults; i++) {
			Variant item = (i < (size_t)result_array.size()) ? result_array[i] : Variant();
			uint8_t kind = (i < binding->result_kinds.size()) ? binding->result_kinds[i] : (uint8_t)WASMTIME_I32;
			if (!variant_to_val(item, kind, p_results[i])) {
				const char *msg = "sandbox: host result type mismatch";
				self->last_error_kind = "host_error";
				self->last_error = msg;
				return wasmtime_trap_new(msg, std::strlen(msg));
			}
		}
		return nullptr;
	}

	uint8_t kind = binding->result_kinds.empty() ? (uint8_t)WASMTIME_I32 : binding->result_kinds[0];
	if (!variant_to_val(first, kind, p_results[0])) {
		const char *msg = "sandbox: host result type mismatch";
		self->last_error_kind = "host_error";
		self->last_error = msg;
		return wasmtime_trap_new(msg, std::strlen(msg));
	}
	for (size_t i = 1; i < p_nresults; i++) {
		uint8_t k = (i < binding->result_kinds.size()) ? binding->result_kinds[i] : (uint8_t)WASMTIME_I32;
		variant_to_val(Variant(), k, p_results[i]);
	}
	return nullptr;
}

Variant WasmSandbox::load(const PackedByteArray &p_bytes) {
	reset();
	if (p_bytes.is_empty()) {
		return fail("load", "empty Wasm module");
	}
	ensure_engine();
	if (engine == nullptr) {
		return fail("load", "failed to create wasmtime engine");
	}

	wasmtime_error_t *error = wasmtime_module_new(engine, p_bytes.ptr(), (size_t)p_bytes.size(), &module);
	if (error != nullptr) {
		module = nullptr;
		return fail("load", take_error(error));
	}

	module_bytes.assign(p_bytes.ptr(), p_bytes.ptr() + p_bytes.size());
	clear_error();
	return true;
}

Variant WasmSandbox::instantiate() {
	reset_instance();
	if (module == nullptr) {
		return fail("not_loaded", "no Wasm module loaded");
	}

	store = wasmtime_store_new(engine, this, nullptr);
	if (store == nullptr) {
		return fail("instantiate", "failed to create wasmtime store");
	}
	ctx = wasmtime_store_context(store);
	if (memory_limit > 0) {
		wasmtime_store_limiter(store, (int64_t)memory_limit, -1, -1, -1, -1);
	}

	linker = wasmtime_linker_new(engine);
	if (linker == nullptr) {
		return fail("instantiate", "failed to create wasmtime linker");
	}

	wasm_importtype_vec_t imports;
	std::memset(&imports, 0, sizeof(imports));
	wasmtime_module_imports(module, &imports);

	std::set<std::string> defined;
	for (size_t i = 0; i < imports.size; i++) {
		const wasm_importtype_t *import = imports.data[i];
		const wasm_name_t *module_name = wasm_importtype_module(import);
		const wasm_name_t *field_name = wasm_importtype_name(import);
		const wasm_externtype_t *extern_type = wasm_importtype_type(import);
		if (wasm_externtype_kind(extern_type) != WASM_EXTERN_FUNC) {
			continue;
		}
		if (name_to_string(module_name) != HOST_MODULE) {
			continue;
		}

		std::string field = name_to_string(field_name).utf8().get_data();
		auto host_it = hosts.find(field);
		if (host_it == hosts.end()) {
			continue;
		}
		if (defined.count(field) != 0) {
			continue;
		}
		if (!host_it->second.is_valid()) {
			wasm_importtype_vec_delete(&imports);
			return fail("host_error", "invalid Callable for host '" + String(field.c_str()) + "'");
		}

		const wasm_functype_t *func_type = wasm_externtype_as_functype_const(extern_type);
		if (func_type == nullptr) {
			continue;
		}

		HostBinding *binding = new HostBinding();
		binding->self = this;
		binding->name = field;
		const wasm_valtype_vec_t *results = wasm_functype_results(func_type);
		for (size_t r = 0; r < results->size; r++) {
			binding->result_kinds.push_back((uint8_t)wasm_valtype_kind(results->data[r]));
		}

		wasmtime_error_t *define_error = wasmtime_linker_define_func(
				linker, HOST_MODULE, std::strlen(HOST_MODULE),
				binding->name.data(), binding->name.size(), func_type,
				&WasmSandbox::host_callback, binding, &WasmSandbox::host_binding_finalizer);
		if (define_error != nullptr) {
			delete binding;
			wasm_importtype_vec_delete(&imports);
			return fail("host_error", take_error(define_error));
		}
		defined.insert(field);
	}
	wasm_importtype_vec_delete(&imports);

	wasm_trap_t *trap = nullptr;
	wasmtime_error_t *error = wasmtime_linker_instantiate(linker, ctx, module, &instance, &trap);
	if (error != nullptr) {
		return fail("instantiate", take_error(error));
	}
	if (trap != nullptr) {
		bool out_of_fuel = false;
		String message = take_trap(trap, out_of_fuel);
		return fail(out_of_fuel ? "fuel_limit" : "trap", message);
	}

	have_instance = true;
	clear_error();
	return true;
}

Variant WasmSandbox::call(const String &p_fn_name, const Array &p_args) {
	if (module == nullptr) {
		return fail("not_loaded", "no Wasm module loaded");
	}
	if (!have_instance) {
		Variant instantiated = instantiate();
		if (instantiated.get_type() == Variant::DICTIONARY) {
			return instantiated;
		}
	}

	wasmtime_error_t *fuel_error = wasmtime_context_set_fuel(ctx, fuel_limit == 0 ? UINT64_MAX : (uint64_t)fuel_limit);
	if (fuel_error != nullptr) {
		return fail("fuel_limit", take_error(fuel_error));
	}

	const CharString fn_utf8 = p_fn_name.utf8();
	wasmtime_extern_t export_item;
	std::memset(&export_item, 0, sizeof(export_item));
	if (!wasmtime_instance_export_get(ctx, &instance, fn_utf8.get_data(), std::strlen(fn_utf8.get_data()), &export_item)) {
		return fail("export_not_found", "Wasm export not found: " + p_fn_name);
	}
	if (export_item.kind != WASMTIME_EXTERN_FUNC) {
		return fail("export_not_found", "Wasm export is not a function: " + p_fn_name);
	}

	wasmtime_func_t function = export_item.of.func;
	wasm_functype_t *func_type = wasmtime_func_type(ctx, &function);
	if (func_type == nullptr) {
		return fail("runtime", "failed to read Wasm function type");
	}
	const wasm_valtype_vec_t *params = wasm_functype_params(func_type);
	const wasm_valtype_vec_t *results = wasm_functype_results(func_type);

	if ((size_t)p_args.size() != params->size) {
		wasm_functype_delete(func_type);
		return fail("bad_args", "expected " + String::num_int64((int64_t)params->size) + " arguments, got " +
				String::num_int64((int64_t)p_args.size()));
	}

	std::vector<wasmtime_val_t> wasm_args(params->size);
	for (size_t i = 0; i < params->size; i++) {
		if (!variant_to_val(p_args[i], (uint8_t)wasm_valtype_kind(params->data[i]), wasm_args[i])) {
			wasm_functype_delete(func_type);
			return fail("bad_args", "argument " + String::num_int64((int64_t)i) + " has an incompatible type");
		}
	}

	std::vector<wasmtime_val_t> wasm_results(results->size);
	std::memset(wasm_results.data(), 0, wasm_results.size() * sizeof(wasmtime_val_t));

	wasm_trap_t *trap = nullptr;
	wasmtime_error_t *error = wasmtime_func_call(ctx, &function,
			wasm_args.empty() ? nullptr : wasm_args.data(), wasm_args.size(),
			wasm_results.empty() ? nullptr : wasm_results.data(), wasm_results.size(),
			&trap);
	wasm_functype_delete(func_type);

	if (error != nullptr) {
		return fail("runtime", take_error(error));
	}
	if (trap != nullptr) {
		bool out_of_fuel = false;
		String message = take_trap(trap, out_of_fuel);
		return fail(out_of_fuel ? "fuel_limit" : "trap", message);
	}

	clear_error();
	if (wasm_results.size() == 0) {
		return Variant();
	}
	if (wasm_results.size() == 1) {
		return val_to_variant(wasm_results[0]);
	}
	Array output;
	for (size_t i = 0; i < wasm_results.size(); i++) {
		output.push_back(val_to_variant(wasm_results[i]));
	}
	return output;
}

void WasmSandbox::register_host(const String &p_name, const Callable &p_callable) {
	std::string name = p_name.utf8().get_data();
	hosts[name] = p_callable;
	if (have_instance) {
		reset_instance();
	}
}

void WasmSandbox::set_memory_limit(int64_t p_bytes) {
	size_t limit = p_bytes > 0 ? (size_t)p_bytes : 0;
	if (limit == memory_limit) {
		return;
	}
	memory_limit = limit;
	if (have_instance) {
		reset_instance();
	}
}

int64_t WasmSandbox::get_memory_limit() const {
	return (int64_t)memory_limit;
}

void WasmSandbox::set_fuel_limit(int64_t p_fuel) {
	fuel_limit = p_fuel > 0 ? (uint64_t)p_fuel : 0;
}

int64_t WasmSandbox::get_fuel_limit() const {
	return fuel_limit == 0 ? 0 : (int64_t)fuel_limit;
}

String WasmSandbox::get_last_error() const {
	return last_error;
}

String WasmSandbox::get_last_error_kind() const {
	return last_error_kind;
}

bool WasmSandbox::is_loaded() const {
	return module != nullptr;
}
