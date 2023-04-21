// jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin
// Basic Hello World program

console_log :: (s: string) #foreign WASM;
alert :: (s: string) #foreign WASM;

wasm_memory_grow :: (index: u64, delta: u64) -> int #intrinsic "llvm.wasm.memory.grow";
wasm_memory_size :: (index: s32) -> u64             #intrinsic "llvm.wasm.memory.size.i64";
#program_export
main :: ()  {
    size := wasm_memory_size(0);
    console_log("Hello Jai WASM!"); // prints to browser console
    alert("Hello Jai WASM!"); 
}

#run {
    #import "Compiler";
    set_build_options_dc(.{ output_path="./public" });
}

// #import "Basic";
