# WASM Contract v1

## Overview
This document defines the interface for WebAssembly modules used as mods in the system.

## Interface
Modules must export the following functions:

### `_mod_init()`
- **Signature**: `() -> i32`
- **Purpose**: Initialization of the module.

### `handle_event(event_id, payload)`
- **Signature**: `(i32, i32) -> i32`
- **Arguments**:
    - `event_id`: The hash of the event name, truncated to a 32-bit signed integer.
    - `payload`: An integer value (i32).
- **Return**: An integer result of the event processing.
- **Constraints**:
    - Payloads must be exactly `i32`. Non-integer or out-of-range payloads produce a controlled error (`bad_args`) and do not execute the module.

## Versioning
- `CONTRACT_VERSION = 1`

## Reserved
Contextual data is reserved for future versions.
