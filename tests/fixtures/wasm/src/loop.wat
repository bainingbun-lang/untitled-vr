(module
  (func (export "handle_event") (param $event_id i32) (param $payload i32) (result i32)
    (loop
      (br 0)
    )
    (i32.const 0)
  )
  (func (export "_mod_init") (result i32)
    (i32.const 0)
  )
)