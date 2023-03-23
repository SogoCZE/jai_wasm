write_string :: (s: string) #foreign WASM;

#program_export "main"
main :: ()  {
    write_string("Hello WASM!");
}

#run {
    #import "Compiler";
    set_build_options_dc(.{ output_path="./public" });
}

#import "Basic";