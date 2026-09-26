(module
  (func (export "neg") (param i32) (result i32)
    local.get 0
    i32.const -1
    i32.add)
  (func (export "big") (result i32)
    i32.const 1000000)
  (func (export "minusbig") (result i32)
    i32.const -1000000)
  (func (export "i64neg") (result i64)
    i64.const -1)
)
