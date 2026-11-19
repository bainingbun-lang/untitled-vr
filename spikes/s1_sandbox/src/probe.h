#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class Probe : public RefCounted {
	GDCLASS(Probe, RefCounted)

protected:
	static void _bind_methods();

public:
	Probe() = default;
	~Probe() override = default;

	String get_version() const;
};

} // namespace godot
