let u8 = null;
let allocated;
const textDecoder = new TextDecoder();

const exported = {
    sigemptyset: () => { },
    sigaction: () => { },
    pthread_mutex_lock: () => { },

    memset: (s, c, n) => {
        const buffer = allocated.buffer;
        const bytes = new Uint8Array(buffer, Number(s), Number(n));
        bytes.fill(c);
        return s;
    },

    write_string: (count, buf, fd) => {
        const string = readString(buf, count);
        console.log(string);
        return count;
    }
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

function readString(pointer, length) {
    const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
    return textDecoder.decode(bytes);
}

WebAssembly.instantiateStreaming(fetch("main.wasm"), imports).then(
    (obj) => {
        allocated = obj.instance.exports.memory;
        u8 = new Uint8Array(allocated.buffer)
        obj.instance.exports.main(BigInt(0));
    }
);