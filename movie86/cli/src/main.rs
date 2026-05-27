use std::process::ExitCode;

use movie86_cli::{run_elf_with_debug, DebugConfig, RunOutcome, StdHost};

fn print_usage(arg0: &str) {
    eprintln!(
        "usage: {arg0} [--trace] [--break-at HEX] [--max-steps N] \
         [--watch HEX]... [--dump-u32 HEX]... <elf-file>"
    );
}

fn parse_u32_hex(s: &str) -> Option<u32> {
    let trimmed = s
        .strip_prefix("0x")
        .or_else(|| s.strip_prefix("0X"))
        .unwrap_or(s);
    u32::from_str_radix(trimmed, 16).ok()
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let progname = args.first().map_or("movie86", String::as_str).to_string();

    let mut cfg = DebugConfig::default();
    let mut path: Option<String> = None;
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

    let mut host = StdHost;
    let outcome = run_elf_with_debug(&bytes, &mut host, &cfg);
    if let RunOutcome::Fault(f) = &outcome {
        eprintln!("movie86: guest fault: {f:?}");
    }
    if let RunOutcome::LoadError(e) = &outcome {
        eprintln!("movie86: load error: {e:?}");
    }
    let code = u8::try_from(outcome.process_exit_code() & 0xff).unwrap_or(1);
    ExitCode::from(code)
}
