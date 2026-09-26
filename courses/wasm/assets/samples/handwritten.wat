(module
  (memory 1 2)
  (table 2 funcref)
  (global $g (mut i32) (i32.const 7))
  (func $add (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (func $bump (global.set $g (i32.add (global.get $g) (i32.const 1))))
  (export "add" (func $add))
  (export "mem" (memory 0))
  (start $bump)
  (data (i32.const 0) "hello")
)
