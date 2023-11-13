#scope_module

WASM :: #library "WASM";

walloc_malloc :: (size: s64) -> *void #foreign WASM "malloc";
walloc_free :: (p: *void) #foreign WASM "free";

#scope_export

walloc_allocator :: Allocator.{walloc_allocator_proc, null};

walloc_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if mode == {
        case .STARTUP;
            return null;

        case .ALLOCATE;
            return walloc_malloc(requested_size);

        case .RESIZE;
            // @TODO: this is probably not so good... 
            return walloc_malloc(requested_size);

        case .FREE;
            print("[Walloc]: FREE\n");
            walloc_free(old_memory);
            return null;

        case;
            context.assertion_failed(#location(), "WALLOC ALLOCATOR DOES NOT SUPPORT FLAG");
            return null;
    }
}

#import "Basic";