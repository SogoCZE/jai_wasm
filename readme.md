# Jai WASM Plugin

A prototype of a Metaprogram Plugin for compiling Jai to wasm32. Currently does not handle heap memory allocations - you could use a JavaScript heap allocator from [Jai Wasm GL](https://github.com/kujukuju/JaiWasmGL). The plan is to implement a heap memory allocator in Jai once the Jai compiler supports WASM LLVM Intrinsics.

## How it works?

- The Metaprogram Plugin sets the LLVM target triple to `wasm64`.
- It then strips all procedure bodies that contain inline assembly (we need to provide non-asm alternatives in the future).
- After, it links the WASM binary with the `wasm-ld`.
- Optionally, it uses the [wasm64232](https://github.com/tsoding/wabt-wasm64232) tool to convert the 64 WASM binary to 32 one (this is currently untested).

## How to use

### Compilation
- A tiny change in `Basic/Print.jai:3` is needed. Change it from `USE_SIMD :: true;` to `USE_SIMD :: CPU == .X64;`.
- Include the WASM Metaprogram Plugin in your `build.jai`. 
- Or compile your program with the following command `jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin`

### JavaScript -> Jai
Define foreign JavaScript functions with a foreign directive in the following way:

```go 
alert :: (s: string) #foreign WASM;
```

### Jai -> JavaScript
Export Jai procedures with `#program_export` directive. Optionally you can specify the export name `#program_export "export_name"`.

```go
#program_export
render :: ()  {
    ...
}
```

When compilation output is set to `executable` main is automatically exported.

## How to compile the Hello World example

- Compile `main.jai` with the WASM metaprogram plugin with the following command `jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin`.
- Serve `public` folder with local HTTP server.

## Credits

This approach is based on [jai-wasm](https://github.com/tsoding/jai-wasm) thanks!