(module
  (func $add (param i64 i64) (result i64) local.get 0 local.get 1 i64.add)
  (func (export "run") (param $n i64) (result i64)
    (local $i i64) (local $acc i64)
    (block $done
      (loop $l
        (br_if $done (i64.ge_u (local.get $i) (local.get $n)))
        (local.set $acc (call $add (local.get $acc) (local.get $i)))
        (local.set $i (i64.add (local.get $i) (i64.const 1)))
        (br $l)))
    (local.get $acc))
  (func (export "spin") (loop $s (br $s)))
)
