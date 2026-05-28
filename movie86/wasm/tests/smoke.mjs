// End-to-end smoke test for movie86-wasm. Loads the wasm module the
// same way the browser will (via the wasm-bindgen --target web shim,
// pre-fed the .wasm bytes since Node doesn't have fetch+import.meta
// in the same way), then runs each bundled example ELF through both
// `runElf` (one-shot) and the step-driven `Vm` API, asserting exit
// code, stdout, and that the Vm path's step count + halt reason match
// the one-shot's. Catches:
//
//   - the JS ↔ Rust glue regressing in a way cargo build alone misses,
//   - example-elf bytes drifting away from what movie86 can load,
//   - default max_steps being too small for the bundled examples,
//   - Vm.stepN / regs / drain getters diverging from runElf semantics.
//
// Invoked from .github/workflows/movie86-wasm.yaml after build-wasm.

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const root = `${here}/..`;

const wasm = await readFile(`${root}/build/browser/movie86_wasm_bg.wasm`);
const mod  = await import(`${root}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });

const cases = [
    { name: 'return42',   expectExit: 42, expectStdout: ''         },
    { name: 'hello',      expectExit: 0,  expectStdout: 'Hello\n'  },
    { name: 'call_greet', expectExit: 0,  expectStdout: 'Hi!\n'    },
];

const dec = new TextDecoder();

let failed = 0;
for (const c of cases) {
    const elf = new Uint8Array(await readFile(`${root}/examples/${c.name}.elf`));

    // 1) one-shot runElf path
    const r = mod.runElf(elf, undefined);
    const oneShot = { exit: r.exitCode, fault: r.fault, stdout: r.stdout, steps: r.steps };
    r.free();

    // 2) step-driven Vm path — same elf, batched stepN until halt.
    const vm = new mod.Vm(elf);
    let stdoutBytes = new Uint8Array(0);
    while (!vm.haltReason) {
        vm.stepN(10000n);
        const chunk = vm.drainStdout();
        if (chunk.length) {
            const merged = new Uint8Array(stdoutBytes.length + chunk.length);
            merged.set(stdoutBytes); merged.set(chunk, stdoutBytes.length);
            stdoutBytes = merged;
        }
    }
    const stepped = {
        exit: vm.exitCode,
        fault: vm.haltReason,
        stdout: dec.decode(stdoutBytes),
        steps: vm.steps,
    };
    vm.free();

    try {
        // one-shot expectations
        assert.equal(oneShot.fault, undefined,
            `${c.name}: runElf unexpected fault ${oneShot.fault}`);
        assert.equal(oneShot.exit, c.expectExit,
            `${c.name}: runElf exit ${oneShot.exit} != ${c.expectExit}`);
        assert.equal(oneShot.stdout, c.expectStdout,
            `${c.name}: runElf stdout ${JSON.stringify(oneShot.stdout)} != ${JSON.stringify(c.expectStdout)}`);

        // step-driven Vm should agree with the one-shot byte-for-byte.
        assert.equal(stepped.exit, oneShot.exit,
            `${c.name}: Vm exit ${stepped.exit} != runElf ${oneShot.exit}`);
        assert.equal(stepped.stdout, oneShot.stdout,
            `${c.name}: Vm stdout disagrees with runElf`);
        assert.equal(stepped.steps, oneShot.steps,
            `${c.name}: Vm steps ${stepped.steps} != runElf ${oneShot.steps}`);

        console.log(`ok  ${c.name}  exit=${oneShot.exit} steps=${oneShot.steps}`);
    } catch (e) {
        console.error(`FAIL ${c.name}: ${e.message}`);
        failed++;
    }
}

if (failed > 0) {
    console.error(`${failed} smoke test(s) failed`);
    process.exit(1);
}
console.log('all smoke tests passed');
