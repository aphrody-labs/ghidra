# Rust

The module provides improved support for binaries written in the Rust programming language.

## Features

- Demanglers for the legacy (`_ZN...E`, also `__ZN` on macOS and `ZN` from dbghelp on Windows)
  and v0 (`_R`) schemes. Malformed `$..$` escapes in legacy symbols are kept verbatim instead
  of aborting the demangle.
- Rust calling convention (`rustcall`) and DWARF function fixups.
- String analyzer that splits non-terminated static strings into slices.
- Rust Panic Analyzer: marks the `core`/`alloc`/`std` panic entry points
  (`core::panicking::panic*`, `unwrap_failed`, `expect_failed`, slice index failures,
  `handle_alloc_error`, ...) as non-returning, and recognises `core::panic::Location`
  structures (`&str` file ending in `.rs`, line, column) in read-only data, creating them and
  labelling them `panic_loc_<file>_<line>_<col>`.
- `RustTypes`: builds the data types `&str`, `&[T]`, `&dyn` (data and vtable pointers), `VTable`
  header (drop_in_place, size, align), `Vec`, `String` (cap, ptr, len order of current rustc),
  `RcInner`/`ArcInner` headers (strong, weak) and `Location`, in the `/rust` category, for 32
  and 64 bit pointers. The `Location` type is applied by the Panic Analyzer.

## Not covered

Applying the types to demangled function signatures, enum niche layouts and async state machine
(`{async_fn#0}`, `{closure#N}`) labelling are not implemented.
