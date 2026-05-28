use std::path::PathBuf;
use std::process::ExitCode;

use gdbstub::stub::DisconnectReason;
use movie86_cli::{
    diff_snapshots, run_elf_with_debug, run_elf_with_gdb, DebugConfig, GdbRunError, RunOutcome,
    StdHost,
};

fn print_usage(arg0: &str) {
    eprintln!(
        "usage: {arg0} [--trace] [--break-at HEX] [--max-steps N] \
         [--watch HEX]... [--dump-u32 HEX]... \
         [--log-writes-in START:END]... \
         [--snapshot-at-step N PATH] [--snapshot-on-stop PATH] \
         [--gdb-listen ADDR] <elf-file>"
    );
    eprintln!();
    eprintln!("subcommands:");
    eprintln!("  {arg0} diff <a.snap> <b.snap>    compare two snapshots");
    eprintln!();
    eprintln!("gdb usage:");
    eprintln!("  {arg0} --gdb-listen 127.0.0.1:1234 prog.elf");
    eprintln!("  $ gdb -ex 'target remote :1234' -ex 'set arch i386'");
}

fn parse_u32_hex(s: &str) -> Option<u32> {
    let trimmed = s
        .strip_prefix("0x")
        .or_else(|| s.strip_prefix("0X"))
        .unwrap_or(s);
    u32::from_str_radix(trimmed, 16).ok()
}

/// Parse `START:END` into a half-open `Range<u32>` (both hex, with
/// or without `0x` prefix). `END` is exclusive — match Rust's `..`
/// range convention.
fn parse_range(s: &str) -> Option<std::ops::Range<u32>> {
    let (a, b) = s.split_once(':')?;
    let start = parse_u32_hex(a)?;
    let end = parse_u32_hex(b)?;
    if end <= start {
        return None;
    }
    Some(start..end)
}

#[allow(clippy::too_many_lines)] // monolithic arg-parse; clarity beats fragmentation here
fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let progname = args.first().map_or("movie86", String::as_str).to_string();

    // The first positional argument selects the subcommand. `diff` is
    // the only non-default one for now; everything else is treated as
    // a path to an ELF.
    if args.get(1).is_some_and(|s| s == "diff") {
        return run_diff_subcommand(&args, &progname);
    }

    let mut cfg = DebugConfig::default();
    let mut path: Option<String> = None;
    let mut gdb_listen: Option<std::net::SocketAddr> = None;
    let mut it = args.into_iter().skip(1);
    while let Some(a) = it.next() {
        match a.as_str() {
            "--trace" => cfg.trace = true,
            "--break-at" => {
                let Some(v) = it.next().and_then(|s| parse_u32_hex(&s)) else {
                    eprintln!("movie86: --break-at needs a hex address");
                    return ExitCode::from(2);
                };
                cfg.break_at = Some(v);
            }
            "--max-steps" => {
                let Some(v) = it.next().and_then(|s| s.parse::<u64>().ok()) else {
                    eprintln!("movie86: --max-steps needs a decimal integer");
                    return ExitCode::from(2);
                };
                cfg.max_steps = Some(v);
            }
            "--watch" => {
                let Some(v) = it.next().and_then(|s| parse_u32_hex(&s)) else {
                    eprintln!("movie86: --watch needs a hex address");
                    return ExitCode::from(2);
                };
                cfg.watch_u32.push(v);
            }
            "--dump-u32" => {
                let Some(v) = it.next().and_then(|s| parse_u32_hex(&s)) else {
                    eprintln!("movie86: --dump-u32 needs a hex address");
                    return ExitCode::from(2);
                };
                cfg.dump_u32.push(v);
            }
            "--snapshot-at-step" => {
                let Some(n) = it.next().and_then(|s| s.parse::<u64>().ok()) else {
                    eprintln!("movie86: --snapshot-at-step needs a decimal step count");
                    return ExitCode::from(2);
                };
                let Some(p) = it.next() else {
                    eprintln!("movie86: --snapshot-at-step needs a path after the step count");
                    return ExitCode::from(2);
                };
                cfg.snapshot_at_step = Some((n, PathBuf::from(p)));
            }
            "--log-writes-in" => {
                let Some(arg) = it.next() else {
                    eprintln!("movie86: --log-writes-in needs START:END (hex)");
                    return ExitCode::from(2);
                };
                let Some(r) = parse_range(&arg) else {
                    eprintln!(
                        "movie86: bad --log-writes-in range {arg:?} (expected START:END, both hex, END > START)"
                    );
                    return ExitCode::from(2);
                };
                cfg.log_writes_in.push(r);
            }
            "--snapshot-on-stop" => {
                let Some(p) = it.next() else {
                    eprintln!("movie86: --snapshot-on-stop needs a path");
                    return ExitCode::from(2);
                };
                cfg.snapshot_on_stop = Some(PathBuf::from(p));
            }
            "--gdb-listen" => {
                let Some(addr) = it.next() else {
                    eprintln!("movie86: --gdb-listen needs an ADDR like 127.0.0.1:1234");
                    return ExitCode::from(2);
                };
                match addr.parse::<std::net::SocketAddr>() {
                    Ok(s) => gdb_listen = Some(s),
                    Err(e) => {
                        eprintln!("movie86: bad --gdb-listen address {addr:?}: {e}");
                        return ExitCode::from(2);
                    }
                }
            }
            "-h" | "--help" => {
                print_usage(&progname);
                return ExitCode::SUCCESS;
            }
            s if s.starts_with('-') => {
                eprintln!("movie86: unknown flag: {s}");
                print_usage(&progname);
                return ExitCode::from(2);
            }
            _ => {
                if path.is_some() {
                    eprintln!("movie86: extra positional argument: {a}");
                    return ExitCode::from(2);
                }
                path = Some(a);
            }
        }
    }

    let Some(path) = path else {
        print_usage(&progname);
        return ExitCode::from(2);
    };

    let bytes = match std::fs::read(&path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("movie86: cannot read {path}: {e}");
            return ExitCode::from(2);
        }
    };

    if let Some(addr) = gdb_listen {
        // gdb attach path is mutually exclusive with the debugger CLI
        // flags — gdb owns the run/stop state machine.
        return run_gdb_path(&bytes, addr);
    }

    let mut host = StdHost::default();
    let outcome = run_elf_with_debug(&bytes, &mut host, &cfg);
    if let RunOutcome::Fault(f) = &outcome {
        eprintln!("movie86: guest fault: {f:?}");
    }
    if let RunOutcome::LoadError(e) = &outcome {
        eprintln!("movie86: load error: {e:?}");
    }
    // DebugStop already printed its own diagnostic from inside the
    // run loop; no extra message needed here.
    let code = u8::try_from(outcome.process_exit_code() & 0xff).unwrap_or(1);
    ExitCode::from(code)
}

/// `--gdb-listen` execution path. Preserves the inferior's
/// termination status so scripts can distinguish clean exit from
/// crash, same as the non-gdb path does for `int 0x80` exits.
///
/// - `TargetExited(code)`     → ExitCode(code)  (guest's syscall arg)
/// - `TargetTerminated(sig)`  → ExitCode(128+sig) (Unix convention)
/// - `Kill`                   → ExitCode(1) (debugger killed it)
/// - `Disconnect`             → ExitCode(0) (user detached cleanly)
/// - load / io / stub errors  → 2 / 2 / 1
fn run_gdb_path(bytes: &[u8], addr: std::net::SocketAddr) -> ExitCode {
    match run_elf_with_gdb(bytes, addr) {
        Ok(reason) => {
            eprintln!("movie86: gdb session ended: {reason:?}");
            match reason {
                DisconnectReason::Disconnect => ExitCode::SUCCESS,
                DisconnectReason::TargetExited(code) => ExitCode::from(code),
                DisconnectReason::TargetTerminated(sig) => {
                    // Unix shells convention: signal-killed exit
                    // status is 128 + signum. `Signal` is a
                    // newtype around u8; `sig.0` is the raw number.
                    let raw = u32::from(sig.0).saturating_add(128);
                    ExitCode::from(u8::try_from(raw & 0xff).unwrap_or(1))
                }
                DisconnectReason::Kill => ExitCode::from(1),
            }
        }
        Err(GdbRunError::Load(e)) => {
            eprintln!("movie86: load error: {e:?}");
            ExitCode::from(2)
        }
        Err(GdbRunError::Io(e)) => {
            eprintln!("movie86: gdb-listen io error: {e}");
            ExitCode::from(2)
        }
        Err(GdbRunError::Stub(msg)) => {
            eprintln!("movie86: gdbstub error: {msg}");
            ExitCode::from(1)
        }
    }
}

/// `movie86 diff <a.snap> <b.snap>` — load two snapshots and print the
/// register / step-count / memory deltas. Exits 0 if they match (no
/// changes), 1 if they differ, 2 on bad arguments / load failure.
fn run_diff_subcommand(args: &[String], progname: &str) -> ExitCode {
    // args[0] = progname, args[1] = "diff", args[2..] = paths
    if args.len() != 4 {
        eprintln!("usage: {progname} diff <a.snap> <b.snap>");
        return ExitCode::from(2);
    }
    let a = match movie86_cli::snapshot::Snapshot::read_from_path(args[2].as_ref()) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("movie86: failed to read {}: {e}", args[2]);
            return ExitCode::from(2);
        }
    };
    let b = match movie86_cli::snapshot::Snapshot::read_from_path(args[3].as_ref()) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("movie86: failed to read {}: {e}", args[3]);
            return ExitCode::from(2);
        }
    };
    let report = diff_snapshots(&a, &b);
    print!("{report}");
    if report.contains("no differences") {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}
