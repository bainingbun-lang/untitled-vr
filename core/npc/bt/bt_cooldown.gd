# Copyright (c) 2016 Jeffery Olson
# Copyright (c) 2016 Brandon Lamb
# Copyright (c) 2017 Sebastian Ebert
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Adapted for Godot 4.7 and UNTITLED project: removed editor dependencies,
# converted to pure GDScript RefCounted, simplified API.

class_name BTCooldown
extends BTDecorator

@export var cooldown_time: float = 1.0

# Decorator Node - Prevents child from executing again until cooldown expires

var _last_execution_time: float = -1.0

func tick(tick: Variant) -> int:
	var current_time: float = 0.0
	if tick.actor and tick.actor.has_method("get_process_time"):
		current_time = tick.actor.get_process_time()
	elif tick.actor and tick.actor.has_method("get_time"):
		current_time = tick.actor.get_time()
	else:
		current_time = Time.get_ticks_msec() / 1000.0
	
	if _last_execution_time >= 0.0 and (current_time - _last_execution_time) < cooldown_time:
		return ERR_BUSY
	
	for child in get_children():
		var result: int = child.execute(tick)
		
		if result == OK or result == FAILED:
			_last_execution_time = current_time
		
		return result
	
	return FAILED

func reset() -> void:
	_last_execution_time = -1.0