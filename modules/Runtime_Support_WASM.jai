#module_parameters(ENABLE_BACKTRACE_ON_CRASH: bool);

WASM :: #library "WASM";

wasm_write        :: (s: string, to_standard_error: bool) #foreign WASM;
wasm_debug_break  :: () #foreign WASM;

// @Cleanup: __element_duplicate should lose its c_call status, and also be faster...!
__element_duplicate :: (start: *u8, num_elements: s64, size: s64) #c_call #no_aoc {
    cursor := start + size;
    for 1..num_elements-1 {
        memcpy(cursor, start, size);
        cursor += size;
    }
}

write_nonnegative_number :: (n: u64, base := 10, to_standard_error := false) #no_context #no_abc #no_aoc {
    if n == 0 {
        write_string("0", to_standard_error);
        return;
    }

    if base > 16  base = 16;
    if base < 2   base = 2;

    ubase := cast(u64) base;

    // This is of course a horrible hack.
    // A u64 in base 2 can be up to 64 digits,
    // so we need at least that much space. Add a few more digits for superstition.
    N :: 69;
    buf: [69] u8;

    starting_cursor : s32 = N;
    cursor := starting_cursor;

    while n { 
        cursor -= 1;
        index := n % ubase;
        if index <= 9 {
            buf[cursor] = cast(u8)(index + #char "0");
        } else {
            buf[cursor] = cast(u8)(index - 10 + #char "a");
        }

        n /= ubase;
    }

    s: string = ---;
    s.data  = buf.data + cursor;
    s.count = starting_cursor - cursor;
    write_string(s, to_standard_error);
}

write_number :: (n: s64, base := 10, to_standard_error := false) #no_context #no_aoc {
    if n < 0 {
        write_string("-", to_standard_error);
        n = -n;
    }

    write_nonnegative_number(cast,no_check(u64) n, base, to_standard_error = to_standard_error);
}

write_loc :: (loc: Source_Code_Location, to_standard_error := false) #no_context {
	write_strings(loc.fully_pathed_filename, ":", to_standard_error = to_standard_error);
	write_number(loc.line_number, to_standard_error = to_standard_error);
	write_string(",", to_standard_error);
	write_number(loc.character_number, to_standard_error = to_standard_error);
}

runtime_support_assertion_failed :: (loc: Source_Code_Location, message: string) {
    write_loc(loc, to_standard_error = true);
	write_string(": Assertion failed", to_standard_error = true);

	if message {
		write_strings(": ", message, "\n", to_standard_error = true);
	} else {
		write_string("!\n", to_standard_error = true);
	}

    print_stack_trace :: (node: *Stack_Trace_Node) {  // @Cutnpaste from modules/Basic, but wihtout calling print.
        while node {
            // There are two different line numbers available.
            // node.info.location has a line number, but this is the location of
            // the start of the procedure. That may be useful in some cases, but often
            // what we really want is the line number of the procedure call, which is
            // stored in node.line_number. That's what we print in this case.

            if node.info {
                write_string(node.info.location.fully_pathed_filename, to_standard_error = true);
                write_string(":", to_standard_error = true);
                write_nonnegative_number(node.line_number, to_standard_error = true);
                write_string(": ", to_standard_error = true);
                if node.info.name write_string(node.info.name, to_standard_error = true);
                else write_string("(anonymous procedure)", to_standard_error = true);
                write_string("\n", to_standard_error = true);
            }

            node = node.next;
        }
    }

    if context.stack_trace {
        write_string("\nStack trace:\n", to_standard_error = true);
        print_stack_trace(context.stack_trace);
    } else {
        write_string("Exiting.\n", to_standard_error = true);
    }

    __runtime_support_disable_stack_trace = true;
    wasm_debug_break();
}

runtime_support_default_logger :: (message: string, data: *void, info: Log_Info) {
    if !message then return;

    to_standard_error := (info.common_flags & .ERROR) != 0;

    if message[message.count-1] != #char "\n" {
        write_strings(message, "\n", to_standard_error = to_standard_error);
    } else {
        write_string(message, to_standard_error = to_standard_error);
    }
}

my_panic :: () #no_context {
    write_string("Panic.\n", to_standard_error = true);
    wasm_debug_break();
}

__panic_due_to_runtime_call_of_compile_time_procedure :: (line_number: s64, filename: *u8) #no_context {
    write_string("Error: Attempt to call a compile-time procedure at runtime. The location of the call was: ", to_standard_error = true);
    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    my_panic();
}

c_style_strlen :: (str: *u8) -> s64 #no_context {
    p := str;
    while << p  { p += 1; }
    return p - str;
}

to_string :: (c_string: *u8) -> string #no_context {
    if c_string == null return "";

    s: string = ---;
    s.data = c_string;
    s.count = c_style_strlen(c_string);

    return s;
}

// @Incomplete: Pass loc to Runtime_Support versions.
__array_bounds_check_fail :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context {
    // @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
    write_string("Array bounds check failed. (The attempted index is ", to_standard_error = true);
    write_number(index, to_standard_error = true);

    if limit > 0 {
        write_string(", but the highest valid index is ", to_standard_error = true);
        write_number(limit-1, to_standard_error = true);
    } else if limit == 0 {
        write_string(", but the array has dimension 0, so no index is valid", to_standard_error = true);
    } else {
        write_string(", but the array has invalid negative dimension ", to_standard_error = true);
        write_number(limit, to_standard_error = true);
    }

    write_string("). Site is ", to_standard_error = true);
    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    my_panic();
}

__cast_bounds_check_fail :: (pre_value: s64, pre_flags: u32, post_value: s64, post_flags: u32, fatal: u8, line_number: s64, filename: *u8) #no_context {
    bits : s32 = 0;

    NUMBER_FLAG_SIGNED   :: 0x40;
    NUMBER_FLAG_8BIT     :: 0x100;
    NUMBER_FLAG_16BIT    :: 0x200;
    NUMBER_FLAG_32BIT    :: 0x400;
    NUMBER_FLAG_64BIT    :: 0x800;

    if post_flags & NUMBER_FLAG_64BIT bits = 64;
    if post_flags & NUMBER_FLAG_32BIT bits = 32;
    if post_flags & NUMBER_FLAG_16BIT bits = 16;
    if post_flags & NUMBER_FLAG_8BIT  bits = 8;

    write_string("Cast bounds check failed.  Number must be in [", to_standard_error = true);

    if post_flags & NUMBER_FLAG_SIGNED {
        high_value := (1 << (bits - 1)) - 1;
        low_value  := ~high_value;
        write_number(low_value, to_standard_error = true);
        write_string(", ", to_standard_error = true);
        write_number(high_value, to_standard_error = true);
    } else {
        // We don't yet have our stringent definition of left-shift, so, we are generating results
        // that will vary on different machines unless we check. So let's check.
        high_value: u64;
        if bits == 64 {
            high_value = 0xffff_ffff_ffff_ffff;
        } else {
            high_value = ((cast(u64)1) << bits) - 1;
        }

        write_string("0, ", to_standard_error = true);
        write_nonnegative_number(high_value, to_standard_error = true);
    }

    write_string("]; it was ", to_standard_error = true);

    if pre_flags & NUMBER_FLAG_SIGNED {
        write_number(pre_value, to_standard_error = true);
    } else {
        write_nonnegative_number(cast,no_check(u64) pre_value, to_standard_error = true);
    }

    write_string(".  Site is ", to_standard_error = true);

	write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
	write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    if fatal my_panic();
}

__null_pointer_check_fail :: (index: s64, line_number: s64, filename: *u8) #no_context {
    // @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
    if index {
        // This is a procedure argument.
        write_string("Null pointer check failed: Argument ", to_standard_error = true);
        write_number(index, to_standard_error = true);
        write_string(" is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
    } else {
        // It was a dereference that happened in some other way.
        write_string("Null pointer check failed: A pointer is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
    }

    write_string(to_string(filename), to_standard_error = true);
    write_string(":", to_standard_error = true);
    write_number(line_number, to_standard_error = true);
    write_string(".\n", to_standard_error = true);

    my_panic();
}

__arithmetic_overflow :: (left: s64, right: s64, type_code: u16, line_number: s64, filename: *u8) #no_context #no_aoc {
    // We have some free bits in type_code...!
    fatal  := (type_code & 0x8000);
    signed := (type_code & 0x4000);
    operator_index := (type_code >> 7) & 0x3;
    size := (cast(u64)(type_code & 0x000f))*8;

    signed_string := ifx signed then "s" else "u";
    operator_string := " / ";
    
    if      operator_index == 1 then operator_string = " + ";
    else if operator_index == 2 then operator_string = " - ";
    else if operator_index == 3 then operator_string = " * ";
    
    write_string("Arithmetic overflow. We tried to compute:\n    ", to_standard_error = true);

    if signed  write_number(left, to_standard_error = true);
    else       write_nonnegative_number(cast,no_check(u64)left, to_standard_error = true);

    write_string(operator_string, to_standard_error = true);
    
    if signed  write_number(right, to_standard_error = true);
    else       write_nonnegative_number(cast,no_check(u64)right, to_standard_error = true);
    
    write_strings("\nThe operand type is ", signed_string, to_standard_error = true);
    write_nonnegative_number(size, to_standard_error = true);
    write_string(", but the result does not fit into this type.\n", to_standard_error = true);
    
    if fatal my_panic();
}

write_string_unsynchronized :: (s: string, to_standard_error := false) #no_context {
    wasm_write(s, to_standard_error);
}

write_string :: (s: string, to_standard_error := false) #no_context #compiler {
    write_string_unsynchronized(s, to_standard_error);
}

write_strings :: (strings: ..string, to_standard_error := false) #no_context #compiler {
    // write_strings is marked #compiler because, if called at compile-time, it
    // involves a different implementation that also syncs with the compiler's output.
    // This runtime version of write_strings is just about syncing the threads
    // in your own program.
    
    for strings write_string_unsynchronized(it, to_standard_error);
}

// TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.

first_thread_context: Context;
first_thread_stack_trace_node: Stack_Trace_Node;
first_thread_temporary_storage: Temporary_Storage;
first_thread_temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;

#program_export
__jai_runtime_init :: () -> *Context #c_call {
    ts := *first_thread_temporary_storage;
    set_initial_data(ts, TEMPORARY_STORAGE_SIZE, first_thread_temporary_storage_data.data);

    first_thread_context.temporary_storage = ts;

    first_thread_context.base.context_info = type_info(Context);

    dummy_context: Context;
    dummy_context.base.context_info = type_info(Context);
    push_context dummy_context {
        // Allocator should not rely on a good context for STARTUP. For other modes, it's fine.
        first_thread_context.allocator.data = runtime_support_default_allocator_proc(.STARTUP, 0, 0, null, null);
    }

    return *first_thread_context;
}

#program_export
__jai_runtime_fini :: (_context: *void) #c_call {
    // Nothing here for now!
    // We don't bother shutting down the default allocator. The OS frees the memory.
}

__instrumentation_first  :: () {
}

__instrumentation_second :: () {
}

#program_export "main"
__system_entry_point :: () -> s32 #c_call {
    __jai_runtime_init();

    push_context first_thread_context {
        // @TODO: WASM!
        /*#if ENABLE_BACKTRACE_ON_CRASH {
            // It's possible we should move the init of the crash handler to after __instrumentation_*, so that
            // plugins can set it? But, plugin inits can crash. So maybe we need some other way for a plugin
            // to say it's taking over the crash handler.

            Handler :: #import "Runtime_Support_Crash_Handler";
            Handler.init();
        }*/

        __instrumentation_first ();
        __instrumentation_second();

        __program_main :: () #runtime_support;
        __program_main();
    }

    return 0;
}

Walloc :: #import "Walloc";

runtime_support_default_allocator_proc :: Walloc.walloc_allocator_proc;

#scope_export

synch_initted: s32 = 0;

