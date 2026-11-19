(module
  (import "host" "add" (func $add (param i64 i64) (result i64)))
  (func (export "run") (result i64)
    i64.const 1
    i64.const 41
    call $add))
