# S3 Wasm Sandbox Fix

## Build
Command: `scons platform=linux arch=arm64 target=template_debug -j4`

## Execution
Command: `bash run_test.sh`

## Output
```
PASS load_loop_module
PASS loop_module_returns_value
PASS fuel_limit_cuts_loop
PASS fuel_limit_last_error
PASS fuel_limit_kind
PASS call_after_fuel_reset
PASS load_memory_module
PASS memory_limit_reported
PASS memory_growth_denied
PASS memory_growth_no_error
PASS load_host_module
PASS host_call_returns_expected
PASS host_call_no_error
PASS load_trap_module
PASS trap_divzero_controlled
PASS trap_divzero_last_error
PASS call_after_trap_works
PASS trap_unreachable_controlled
PASS invalid_module_controlled
PASS call_without_module_controlled
CHECKS 20 FAILURES 0
ALL PASS
```

## Results
Exit code: 0
Source: `libwasmtime.a` (v50.0.2)
Known issues: None
Android: Not verified
