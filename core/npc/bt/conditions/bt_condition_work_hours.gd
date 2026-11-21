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
# Adapted for Godot 4.7 and UNTITLED project: work hours condition.

class_name BTConditionWorkHours
extends BTCondition

@export var work_start_hour: float = 9.0
@export var work_end_hour: float = 18.0
@export var lunch_start_hour: float = 12.0
@export var lunch_end_hour: float = 14.0

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null:
		return false
	
	var blackboard = context.blackboard
	var sim_hour = blackboard.get_value("sim_hour", context.tree) or 12.0
	
	if sim_hour >= work_start_hour and sim_hour < lunch_start_hour:
		return true
	if sim_hour >= lunch_end_hour and sim_hour < work_end_hour:
		return true
	
	return false