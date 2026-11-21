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

class_name BTParallel
extends BTComposite

enum Policy {
	SUCCEED_ON_ONE,
	SUCCEED_ON_ALL,
	FAIL_ON_ONE,
	FAIL_ON_ALL
}

@export var success_policy: int = Policy.SUCCEED_ON_ALL
@export var failure_policy: int = Policy.FAIL_ON_ONE

# Parallel Node - ticks all children each tick
# Success/failure policy determines when to return OK/FAILED

func tick(tick: Variant) -> int:
	var children_count: int = get_child_count()
	if children_count == 0:
		return OK
	
	var success_count: int = 0
	var failure_count: int = 0
	var running_count: int = 0
	
	for child in get_children():
		var result: int = child.execute(tick)
		
		match result:
			OK:
				success_count += 1
			FAILED:
				failure_count += 1
			ERR_BUSY:
				running_count += 1
			_:
				running_count += 1
	
	# Check failure policy
	if failure_policy == Policy.FAIL_ON_ONE and failure_count > 0:
		return FAILED
	if failure_policy == Policy.FAIL_ON_ALL and failure_count == children_count:
		return FAILED
	
	# Check success policy
	if success_policy == Policy.SUCCEED_ON_ONE and success_count > 0:
		return OK
	if success_policy == Policy.SUCCEED_ON_ALL and success_count == children_count:
		return OK
	
	# If any child is running, we're running
	if running_count > 0:
		return ERR_BUSY
	
	# Default
	return FAILED