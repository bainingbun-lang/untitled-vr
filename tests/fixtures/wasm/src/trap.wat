(module
  (func (export "handle_event") (param $event_id i32) (param $payload i32) (result i32)
    (i32.div_s (i32.const 1) (i32.const 0))
  )
  (func (export "_mod_init") (result i32)
    (i32.const 0)
  )
)