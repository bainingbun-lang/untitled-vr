# Untitled Sandbox Native Extension

Combined native extension containing Probe, LuaSandbox, and WasmSandbox.

## Build
Run from `native/untitled_sandbox/`:
```bash
scons platform=linux arch=arm64 target=template_debug
```

## Verification
Run the following tests using the combined `.so`:
- S1 (Probe): `bash spikes/s1_sandbox/run_test.sh`
- S2 (Lua): `bash spikes/s2_lua/run_test.sh`
- S3 (Wasm): `bash spikes/s3_wasm/run_test.sh`

## Test Results
- S1 (Probe): PASS
- S2 (Lua): PASS (20/20)
- S3 (Wasm): PASS (20/20)

## Sources Used
- `spikes/s1_sandbox/src/probe.cpp`
- `spikes/s2_lua/src/lua_sandbox.cpp`
- `spikes/s3_wasm/src/wasm_sandbox.cpp`
- `spikes/s3_wasm/src/pthread_atfork_shim.cpp`
- `native/untitled_sandbox/src/register_types.cpp` (Custom combined registration)

## Changes from Spikes
- Created a unified `register_types.cpp` in `native/untitled_sandbox/src/` to register all three classes (`Probe`, `LuaSandbox`, `WasmSandbox`) in a single GDExtension entry point.
- Configured `SConstruct` to link against both Lua and Wasmtime libraries in one binary.
