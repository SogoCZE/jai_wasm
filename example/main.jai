// jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin
// Basic Hello World program

console_log :: (s: string) #foreign WASM;
alert :: (s: string) #foreign WASM;

#program_export "main"
main :: ()  {
    console_log("Hello Jai WASM!"); // prints to browser console
    alert("Hello Jai WASM!"); 
}

#run {
    #import "Compiler";
    set_build_options_dc(.{ output_path="./public" });
}

#import "Basic";