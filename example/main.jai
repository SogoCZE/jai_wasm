// jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin
// Basic Hello World program

main :: ()  {
    numbers: [..]int;

    array_add(*numbers, 10);
    array_add(*numbers, 20);
    array_add(*numbers, 30);

    print("Hello Jai! %\n", numbers);

    assert(numbers.count == 4, "Array size does not match!");
}

#run {
    #import "Compiler";
    set_build_options_dc(.{ output_path="./public" });
}

#import "Basic";