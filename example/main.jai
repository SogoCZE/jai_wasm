// jai main.jai -plug wasm --- import_dir /path/to/wasm/plugin
// when running from git repo: jai main.jai -plug wasm --- import_dir ../

// Basic Hello World program

main :: ()  {
    numbers: [..]int;

    array_add(*numbers, 10);
    array_add(*numbers, 20);
    array_add(*numbers, 30);

    print("Hello Jai!\n");

    for numbers {
        print("numbers[%]: %\n", it_index, it);
    }

    builder: String_Builder;

    for 0..10 {
        append(*builder, sprint("Entry-%\n", it));
    }
    print("Builder result: \n%", builder_to_string(*builder));

    // assert(false, "Assert test");
}

#run {
    #import "Compiler";
    set_build_options_dc(.{ output_path="./public" });
}

#import "Basic";