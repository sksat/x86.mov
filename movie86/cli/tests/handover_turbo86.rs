//! End-to-end handover test: spawn a real turbo86 server, drive it
//! from movie86-cli's WS handover client, assert the round trip
//! lands at the expected outcome.
//!
//! Requires the Go toolchain on PATH (or a pre-built turbo86 binary
//! at `$TURBO86_BIN`). Skipped otherwise — keeping movie86's Rust-only
//! CI honest while still letting humans (or a Go-equipped CI lane)
//! run it.

use std::env;
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use movie86::{Context, MemRegion, Regs};
use movie86_cli::handover::HandoverClient;
use movie86_cli::turbo86_wire::{Inbound, Mode, Outbound};

/// RAII wrapper that kills the spawned turbo86 on drop so an early
/// panic in the test body doesn't leak the subprocess.
struct ChildGuard<'a>(&'a mut Child);
impl Drop for ChildGuard<'_> {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

/// Resolve the turbo86 binary. Either:
/// - `TURBO86_BIN=...` points at an already-built executable, or
/// - `go` is on PATH and the turbo86 source is at the repo's
///   `turbo86/` (relative to the workspace root), in which case we
///   `go build` once into a tempdir.
///
/// Returns `None` if neither is available — the test then skips.
fn locate_turbo86() -> Option<PathBuf> {
    if let Ok(p) = env::var("TURBO86_BIN") {
        let path = PathBuf::from(p);
        if path.is_file() {
            return Some(path);
        }
        eprintln!("TURBO86_BIN points at non-file path; ignoring");
    }
    Command::new("go").arg("version").output().ok()?;
    // Workspace layout: this test runs from `movie86/cli/`; turbo86
    // sources are at `<repo>/turbo86/`. CARGO_MANIFEST_DIR points at
    // the cli crate, so go up two levels.
    let manifest = env::var("CARGO_MANIFEST_DIR").ok()?;
    let turbo86_src = PathBuf::from(manifest).join("../../turbo86");
    let turbo86_src = turbo86_src.canonicalize().ok()?;
    if !turbo86_src.join("go.mod").is_file() {
        return None;
    }
    let out = env::temp_dir().join(format!("turbo86-handover-test-{}", std::process::id()));
    let status = Command::new("go")
        .arg("build")
        .arg("-o")
        .arg(&out)
        .arg("./cmd/turbo86")
        .current_dir(&turbo86_src)
        .status()
        .ok()?;
    if !status.success() {
        return None;
    }
    Some(out)
}

/// Spawn turbo86 listening on a free port. Returns the child handle
/// and the connect URL. Caller is responsible for killing the child.
fn spawn_turbo86(bin: &PathBuf) -> (Child, String) {
    // Bind a free port by asking the kernel, then release it before
    // turbo86 grabs it. There's a TOCTOU window but the alternative
    // (parsing turbo86's startup banner) needs structured log output
    // turbo86 doesn't emit.
    let port = {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("port probe");
        let p = listener.local_addr().unwrap().port();
        drop(listener);
        p
    };
    let addr = format!("127.0.0.1:{port}");
    let child = Command::new(bin)
        .arg("--addr")
        .arg(&addr)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn turbo86");

    // Wait for the port to accept TCP. Bounded so a stuck server
    // surfaces as a test failure rather than a CI hang.
    let deadline = Instant::now() + Duration::from_secs(5);
    while Instant::now() < deadline {
        if TcpStream::connect(&addr).is_ok() {
            break;
        }
        thread::sleep(Duration::from_millis(20));
    }
    let url = format!("ws://{addr}");
    (child, url)
}

const ENTRY: u32 = 0x0804_8000;
const STACK_TOP: u32 = 0x701F_FFF0;

/// The headline handoff E2E: movie86 builds a Context whose regs +
/// regions encode `exit(42)` (eax=1, ebx=42, eip pointing at `int
/// 0x80` byte). Hand it to turbo86 via `LoadContext`, expect
/// `Exit{42}` on the wire.
///
/// Proves: Rust-side wire codec ↔ Go-side wire codec are
/// byte-compatible, the receive side of turbo86's `LoadContext`
/// works with a movie86-shaped Context, and the resulting kernel
/// exit flows back through the bridge as the canonical Exit
/// Outbound.
#[test]
fn handover_load_context_exit_round_trip_through_real_turbo86() {
    let Some(bin) = locate_turbo86() else {
        eprintln!(
            "skipping: neither TURBO86_BIN set nor `go build ../../turbo86/cmd/turbo86` available"
        );
        return;
    };

    let (mut child, url) = spawn_turbo86(&bin);
    let _guard = ChildGuard(&mut child);

    let ctx = Context {
        regs: Regs {
            eax: 1, // SYS_exit
            ebx: 42,
            eip: ENTRY,
            esp: STACK_TOP,
            ..Default::default()
        },
        regions: vec![MemRegion {
            addr: ENTRY,
            bytes: vec![0xcd, 0x80], // int 0x80
        }],
        reservations: vec![],
    };

    let mut client = HandoverClient::connect(&url).expect("connect turbo86");
    client
        .send(&Inbound::LoadContext {
            context: ctx,
            mode: Mode::Host,
        })
        .expect("send LoadContext");

    let events = client.recv_until_session_end().expect("recv until end");
    assert_eq!(
        events,
        vec![Outbound::Exit(42)],
        "expected a single Exit(42) event; got {events:#?}"
    );
}
