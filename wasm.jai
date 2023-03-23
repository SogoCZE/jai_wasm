Plugin :: Metaprogram_Plugin;

WASM_Plugin :: struct {
    #as using base: Plugin;
    should_run := true;
}

get_plugin :: () -> *Plugin {
    p := New(WASM_Plugin);

    p.message  = message;
    p.shutdown = shutdown;
    p.add_source = add_source;
    p.before_intercept = before_intercept;

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
    options.llvm_options.target_system_triple = "wasm64";
    options.llvm_options.function_sections = true; // To get around "LLVM ERROR: section already has a defining function: .text"
    options.use_custom_link_command = true; // wasm-ld
    options.output_type = .DYNAMIC_LIBRARY;
    options.lazy_foreign_function_lookups = true; 
    // options.os_target = .NONE; 

    import_paths: [..]string;

    for options.import_path array_add(*import_paths, it);

    array_add(*import_paths, tprint("%modules", #filepath));

    options.import_path = import_paths; 

    // remap_import(p.workspace, "*", "Runtime_Support", "Runtime_Support_WASM");

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

        if contains_asm {
            body := it.expression;
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
    o := get_build_options(p.workspace);

    if message.kind == .TYPECHECKED remove_asm_blocks(p, xx message, p.workspace);

    if message.kind == .PHASE {
        phase := cast(*Message_Phase) message;
            
        if phase.phase == .READY_FOR_CUSTOM_LINK_COMMAND {
            wasm64232_name: string;

            if OS == {
                case .WINDOWS;
                    wasm64232_name = "wasm64232_windows.exe";
                case .MACOS;
                    wasm64232_name = "wasm64232_mac";
                case .LINUX;
                    wasm64232_name = "wasm64232_linux";
            }

            object_path := phase.compiler_generated_object_files[0];

            STACK_SIZE :: 4194304 - 1024 * 12;

            wasm64_file_path := tprint("%/%_64.wasm", path_strip_filename(object_path), o.output_executable_name);
            wasm32_file_path := tprint("%/%.wasm", o.output_path, o.output_executable_name);

            cmd("wasm-ld", "-mwasm64", "--no-entry", "--stack-first", "--export-all", "-z", tprint("stack-size=%", STACK_SIZE), "--allow-undefined", object_path, "-o", wasm64_file_path);
            cmd(tprint("%/tools/%", #filepath, wasm64232_name), "-o", wasm32_file_path, wasm64_file_path);
            compiler_custom_link_command_is_complete(p.workspace);
        }
    }

}

shutdown :: (_p: *Plugin) {
    p := cast(*WASM_Plugin) _p;
    free(p);
}

#import "Basic";
#import "String";
#import "Compiler";
#import "Process";