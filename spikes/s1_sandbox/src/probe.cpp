#include "probe.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void Probe::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_version"), &Probe::get_version);
}

String Probe::get_version() const {
	return "s1";
}
