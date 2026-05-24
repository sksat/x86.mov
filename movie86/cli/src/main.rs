use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let Some(path) = args.get(1) else {
        eprintln!(
            "usage: {} <elf-file>",
            args.first().map_or("movie86", String::as_str)
        );
        return ExitCode::from(2);
    };

    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("movie86: cannot read {path}: {e}");
            return ExitCode::from(2);
        }
    };

    let outcome = movie86_cli::run_elf(&bytes);
    if let movie86_cli::RunOutcome::Fault(f) = &outcome {
        eprintln!("movie86: guest fault: {f:?}");
    }
    if let movie86_cli::RunOutcome::LoadError(e) = &outcome {
        eprintln!("movie86: load error: {e:?}");
    }
    let code = u8::try_from(outcome.process_exit_code() & 0xff).unwrap_or(1);
    ExitCode::from(code)
}
