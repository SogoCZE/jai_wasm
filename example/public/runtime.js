let allocated;
const textDecoder = new TextDecoder();

function readString(pointer, length) {
    const u8 = new Uint8Array(allocated.buffer)
    const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
    return textDecoder.decode(bytes);
}

let console_buffer = "";
let console_timeout = null;

function write_to_console_log(str) {
    clearTimeout(console_timeout);
    console_buffer += str;

    if (str.includes("\n")) {
        console.log(console_buffer);
        console_buffer = "";
        return;
    }

    console_timeout = setTimeout(() => {
        console.log(console_buffer);
        console_buffer = "";
    }, 3);
}

const exported = {
    wasm_write: (count, buf) => {
        const string = readString(buf, count);
        write_to_console_log(string);
        return count;
    },

    wasm_debug_break: () => {
        debugger;
    },

    alert: (count, buf) => {
        const string = readString(buf, count);
        alert(string);
        return count;
    },
}

const imports = {
    "env": new Proxy(exported, {
        get(target, prop, receiver) {
            if (target.hasOwnProperty(prop)) {
                return target[prop];
            }

            return () => console.error("Missing function: " + prop);
        },
    }),
}


WebAssembly.instantiateStreaming(fetch("main.wasm"), imports).then(
    (obj) => {
        allocated = obj.instance.exports.memory;
        obj.instance.exports.main(BigInt(0));
    }
);