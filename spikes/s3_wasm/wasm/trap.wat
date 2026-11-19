(module
  (func (export "divzero") (result i32)
    i32.const 1
    i32.const 0
    i32.div_s)
  (func (export "unreachable") unreachable)
  (func (export "ok") (result i32)
    i32.const 7))
