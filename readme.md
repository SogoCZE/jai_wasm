# Jai WASM Plugin

A prototype of a Metaprogram Plugin for compiling Jai to wasm32. Currently does not handle heap memory allocations - you could use a JavaScript heap allocator from [Jai Wasm GL](https://github.com/kujukuju/JaiWasmGL). The plan is to implement a heap memory allocator in Jai once the Jai compiler supports WASM LLVM Intrinsics.

## How it works?

- The Metaprogram Plugin sets the LLVM target triple to `wasm64`.
- It then strips all procedure bodies that contain inline assembly (we need to provide non-asm alternatives in the future).
- After, it links the WASM binary with the `wasm-ld`.
- Finally, it uses the [wasm64232](https://github.com/tsoding/wabt-wasm64232) tool to convert the 64 WASM binary to 32 one.

## TODO
- Implement heap memory allocator in Jai (waiting for the compiler to support WASM LLVM Intrinsics)
- Implement `memset` and `memcpy` in Jai or use LLVM WASM intrinsics [(memory.fill, memory.copy)](https://webassembly.github.io/bulk-memory-operations/).
- Provide and replace the default `runtime support` and `preload` modules with ones crafted for the WASM environment.

## How to use


### Calling foreign JavaScript functions
Define foreign JavaScript functions with a foreign directive in the following way:

```c++ 
alert :: (s: string) #foreign WASM;
```

### Compilation

- Include the WASM Metaprogram Plugin in your `build.jai`. 
- Or compile your program with the following command `jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin`

## How to compile hello world example

- Compile `main.jai` with the WASM metaprogram plugin with the following command `jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin`.
- Serve `public` folder with local HTTP server.