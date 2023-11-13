Plugin :: Metaprogram_Plugin;

WASM_Plugin :: struct {
    #as using base: Plugin;
    should_run := true;
    wasm64232_path: string;
}

get_plugin :: () -> *Plugin {
    p := New(WASM_Plugin);

    p.message  = message;
    p.shutdown = shutdown;
    p.add_source = add_source;
    p.before_intercept = before_intercept;

    wasm64232_name: string;
    if OS == {
        case .WINDOWS;
            wasm64232_name = "wasm64232_windows.exe";
        case .MACOS;
            wasm64232_name = "wasm64232_mac";
        case .LINUX;
            wasm64232_name = "wasm64232_linux";
    }

    p.wasm64232_path = get_absolute_path(tprint("%tools/%", #filepath, wasm64232_name));
    return p;
}

add_source :: (_p: *Metaprogram_Plugin) {
    p := cast(*WASM_Plugin) _p;
    add_build_string("WASM :: #library \"WASM\";", p.workspace);
}

before_intercept :: (_p: *Plugin, flags: *Intercept_Flags) {
    p := cast(*WASM_Plugin) _p;

    options := get_build_options(p.workspace);

    options.llvm_options.enable_split_modules = false;
    options.llvm_options.function_sections = true; // To get around "LLVM ERROR: section already has a defining function: .text"
    options.llvm_options.target_system_triple = "wasm64-unknown-unknown";
    options.llvm_options.target_system_features = "+bulk-memory";
    options.use_custom_link_command = true; // wasm-ld
    options.output_type = .EXECUTABLE;
    options.lazy_foreign_function_lookups = true;
    options.cpu_target = .CUSTOM;
    options.emit_debug_info = .DWARF;

    import_paths: [..]string;

    for options.import_path array_add(*import_paths, it);

    array_add(*import_paths, tprint("%modules", #filepath));

    options.import_path = import_paths;

    remap_import(p.workspace, "*", "Runtime_Support", "Runtime_Support_WASM");

    set_build_options(options, p.workspace);

}

remove_asm_blocks :: (p: *WASM_Plugin, tc: *Message_Typechecked, w: Workspace) {
    for tc.procedure_bodies {
        contains_asm := false;
        for it.subexpressions {
            if it.kind == .ASM {
                contains_asm = true;
                break;
            }
        }
        
        body := it.expression;

        // Skipping removal of ASM in 'print_to_builder'. Make sure you have edited modules/Basic/Print:3 to 'USE_SIMD :: CPU == .X64;'
        if contains_asm && body.header.name == "print_to_builder" {
            return;
        }

        if contains_asm {
            log("Removing body of \"%\" because it contains #asm", body.header.name);
            new_statements: [..] *Code_Node;
            body.block.statements = new_statements;
            compiler_modify_procedure(w, body);
        }
    }
}

cmd :: (args: .. string, loc := #caller_location) {
    log("[CMD] %\n", get_quoted_command_string(args));

    result, output_string, error_string := run_command(..args);
    if result.exit_code {
        if output_string then log("%", output_string);
        if error_string then log("%", error_string);
        compiler_report(tprint("Command failed with exit code '%'.\n", result.exit_code), loc);
        exit(result.exit_code);
    }
}

message :: (_p: *Plugin, message: *Message) {
    p := cast(*WASM_Plugin) _p;

    if message.kind == .TYPECHECKED remove_asm_blocks(p, xx message, p.workspace);

    if message.kind == .PHASE {
        phase := cast(*Message_Phase) message;

        if phase.phase == .READY_FOR_CUSTOM_LINK_COMMAND {
            o := get_build_options(p.workspace);

            object_path := phase.compiler_generated_object_files[0];


            wasm64_file_path := tprint("%/%_64.wasm", path_strip_filename(object_path), o.output_executable_name);
            wasm32_file_path := tprint("%/%.wasm", o.output_path, o.output_executable_name);


            // Old wasm-ld link with predefined stack-size (which seems unnecessary):
            // STACK_SIZE :: 24 * 1024;
            // cmd("wasm-ld", "-mwasm64", "--no-entry", "--stack-first", "--export-all", "-z", tprint("stack-size=%", STACK_SIZE), "--import-undefined", object_path, "./walloc.o", "-o", wasm32_file_path);
            
            cmd("wasm-ld", "-mwasm64", "--no-entry", "--export-all", "--import-undefined", object_path, "./walloc.o", "-o", wasm32_file_path);
            // cmd(p.wasm64232_path, "-o", wasm32_file_path, wasm64_file_path); // Converting the 64 wasm to 32 one
            compiler_custom_link_command_is_complete(p.workspace);
        }
    }

}

shutdown :: (_p: *Plugin) {
    p := cast(*WASM_Plugin) _p;
    free(p);
}

#import "Basic";
#import "Compiler";
#import "File";
#import "Process";
#import "String";
