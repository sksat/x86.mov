//! Sync WebSocket handover client for talking to turbo86.
//!
//! Thin wrapper over `tungstenite` that handles the turbo86 wire
//! protocol: marshal Inbound frames out, unmarshal Outbound frames
//! in. The wire details live in [`crate::turbo86_wire`]; this module
//! just owns the transport and the event-loop helper.
//!
//! Use shape:
//! ```no_run
//! use movie86_cli::handover::HandoverClient;
//! use movie86_cli::turbo86_wire::{Inbound, Mode, Outbound};
//! use movie86::{Context, Regs};
//!
//! let mut client = HandoverClient::connect("ws://127.0.0.1:1234").unwrap();
//! let ctx = Context { regs: Regs::default(), regions: vec![] };
//! client.send(&Inbound::LoadContext { context: ctx, mode: Mode::Host }).unwrap();
//! while let Ok(Some(ev)) = client.recv() {
//!     match ev {
//!         Outbound::Exit(code) => println!("exit {code}"),
//!         _ => {}
//!     }
//! }
//! ```

use std::fmt;
use std::io::{Read, Write};
use std::net::TcpStream;

use tungstenite::{
    client::IntoClientRequest,
    protocol::{Message, WebSocketConfig},
    stream::MaybeTlsStream,
    WebSocket,
};

use crate::turbo86_wire::{marshal_inbound, unmarshal_outbound, Inbound, Outbound};

/// Errors the client can surface. The wire-layer errors are wrapped
/// rather than re-exported so callers can ignore tungstenite as an
/// implementation detail.
#[derive(Debug)]
pub enum HandoverError {
    /// Underlying transport (TCP / WS frame) error.
    Transport(String),
    /// Wire-format error (couldn't encode/decode JSON).
    Wire(String),
    /// Server sent a non-text frame, which the protocol doesn't use.
    UnexpectedFrame(String),
}

impl fmt::Display for HandoverError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Transport(s) => write!(f, "handover transport error: {s}"),
            Self::Wire(s) => write!(f, "handover wire error: {s}"),
            Self::UnexpectedFrame(s) => write!(f, "handover unexpected frame: {s}"),
        }
    }
}

impl std::error::Error for HandoverError {}

impl From<tungstenite::Error> for HandoverError {
    fn from(e: tungstenite::Error) -> Self {
        Self::Transport(e.to_string())
    }
}

impl From<serde_json::Error> for HandoverError {
    fn from(e: serde_json::Error) -> Self {
        Self::Wire(e.to_string())
    }
}

/// WebSocket connection to turbo86. Held for the duration of one
/// session (one `LoadContext` + the events that follow).
///
/// Generic over the stream type so tests can use a plain [`TcpStream`]
/// while production uses `MaybeTlsStream<TcpStream>` from tungstenite's
/// `connect` helper.
#[allow(missing_debug_implementations)] // tungstenite::WebSocket<S> doesn't expose Debug for arbitrary S; not worth a hand-rolled fmt
pub struct HandoverClient<S: Read + Write = MaybeTlsStream<TcpStream>> {
    ws: WebSocket<S>,
}

impl HandoverClient<MaybeTlsStream<TcpStream>> {
    /// Connect to `url` (e.g. `ws://127.0.0.1:1234`). TLS / `wss://`
    /// is not enabled in this build of tungstenite — pass a plain
    /// `ws://` URL.
    ///
    /// # Errors
    ///
    /// Returns [`HandoverError::Transport`] on DNS, TCP, or
    /// WebSocket-handshake failure.
    pub fn connect(url: &str) -> Result<Self, HandoverError> {
        let req = url
            .into_client_request()
            .map_err(|e| HandoverError::Transport(format!("bad URL {url:?}: {e}")))?;
        let (ws, _resp) =
            tungstenite::client::connect_with_config(req, Some(WebSocketConfig::default()), 0)?;
        Ok(Self { ws })
    }
}

impl<S: Read + Write> HandoverClient<S> {
    /// Wrap an already-handshaken WebSocket. Used by tests that set
    /// up a mock server via `tungstenite::accept` and want to drive
    /// the client side from the same process.
    #[must_use]
    pub fn from_websocket(ws: WebSocket<S>) -> Self {
        Self { ws }
    }

    /// Send one Inbound. Maps to a single text WebSocket frame
    /// — turbo86 reads one Inbound per frame.
    ///
    /// # Errors
    ///
    /// [`HandoverError::Wire`] on JSON encode failure (unreachable
    /// for the in-memory path) or [`HandoverError::Transport`] on
    /// WebSocket write failure.
    pub fn send(&mut self, msg: &Inbound) -> Result<(), HandoverError> {
        let bytes = marshal_inbound(msg)?;
        let text = std::str::from_utf8(&bytes)
            .map_err(|e| HandoverError::Wire(format!("non-utf8 marshal output: {e}")))?;
        self.ws.send(Message::text(text))?;
        Ok(())
    }

    /// Read one Outbound, or `None` if the server closed the
    /// connection cleanly (= the session ended naturally).
    ///
    /// Ignores Ping/Pong/Close control frames at the protocol level
    /// — tungstenite handles ping/pong automatically, and a Close
    /// is reported as the next read returning a clean Close.
    ///
    /// # Errors
    ///
    /// [`HandoverError::Transport`] on socket read errors,
    /// [`HandoverError::Wire`] on JSON parse failure,
    /// [`HandoverError::UnexpectedFrame`] for a binary frame (the
    /// turbo86 wire is text-only).
    pub fn recv(&mut self) -> Result<Option<Outbound>, HandoverError> {
        loop {
            let msg = match self.ws.read() {
                Ok(m) => m,
                Err(tungstenite::Error::ConnectionClosed) => return Ok(None),
                Err(e) => return Err(e.into()),
            };
            match msg {
                Message::Text(t) => return Ok(Some(unmarshal_outbound(t.as_bytes())?)),
                Message::Binary(_) => {
                    return Err(HandoverError::UnexpectedFrame(
                        "binary frame (turbo86 wire is text-only)".into(),
                    ));
                }
                Message::Close(_) => return Ok(None),
                // Ping/Pong are auto-handled by tungstenite; the
                // surrounding `loop` cycles for the next data frame.
                Message::Ping(_) | Message::Pong(_) | Message::Frame(_) => {}
            }
        }
    }

    /// Read events until the session ends (server closes the WS),
    /// returning everything received. Convenience wrapper for tests
    /// and the simple "send `LoadContext`, read to completion" flow.
    ///
    /// # Errors
    ///
    /// Surfaces the first read error if one happens before clean
    /// closure.
    pub fn recv_until_session_end(&mut self) -> Result<Vec<Outbound>, HandoverError> {
        let mut events = Vec::new();
        while let Some(ev) = self.recv()? {
            events.push(ev);
        }
        Ok(events)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::turbo86_wire::Mode;
    use movie86::{Context, MemRegion, Regs};
    use std::net::{TcpListener, TcpStream};
    use std::sync::mpsc;
    use std::thread;
    use std::time::Duration;

    /// Bind a localhost listener and spawn a thread that accepts one
    /// connection, runs `script` against the resulting server-side
    /// WebSocket, and drops the connection. Returns the bound port
    /// for the client to connect to.
    fn spawn_mock_server<F>(script: F) -> u16
    where
        F: FnOnce(&mut WebSocket<TcpStream>) + Send + 'static,
    {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
        let port = listener.local_addr().unwrap().port();
        let (ready_tx, ready_rx) = mpsc::channel::<()>();
        thread::spawn(move || {
            // Signal the test it can dial.
            let _ = ready_tx.send(());
            let (stream, _) = listener.accept().expect("accept");
            stream.set_read_timeout(Some(Duration::from_secs(5))).ok();
            stream.set_write_timeout(Some(Duration::from_secs(5))).ok();
            let mut ws = tungstenite::accept(stream).expect("handshake");
            script(&mut ws);
            let _ = ws.close(None);
        });
        // Wait until the listener is up before returning the port —
        // the OS binds eagerly, but waiting on the channel makes the
        // intent explicit and survives any future refactor.
        let _ = ready_rx.recv();
        port
    }

    #[test]
    fn client_sends_load_context_and_reads_exit() {
        let port = spawn_mock_server(|ws| {
            let frame = ws.read().expect("read load_context").into_text().unwrap();
            let v: serde_json::Value = serde_json::from_str(&frame).unwrap();
            assert_eq!(v["type"], "load_context");
            assert_eq!(v["mode"], "host");
            assert_eq!(v["context"]["regs"]["eax"], 1);
            ws.send(Message::text(r#"{"type":"exit","code":42}"#))
                .unwrap();
        });

        let url = format!("ws://127.0.0.1:{port}");
        let mut client = HandoverClient::connect(&url).expect("connect");
        let ctx = Context {
            regs: Regs {
                eax: 1,
                ebx: 42,
                eip: 0x1000,
                esp: 0x2000,
                ..Default::default()
            },
            regions: vec![MemRegion {
                addr: 0x1000,
                bytes: vec![0xcd, 0x80],
            }],
        };
        client
            .send(&Inbound::LoadContext {
                context: ctx,
                mode: Mode::Host,
            })
            .unwrap();
        let events = client.recv_until_session_end().unwrap();
        assert_eq!(events, vec![Outbound::Exit(42)]);
    }

    #[test]
    fn client_collects_stdout_then_exit() {
        let port = spawn_mock_server(|ws| {
            let _ = ws.read().expect("read load_context");
            ws.send(Message::text(r#"{"type":"stdout","bytes":"SGk="}"#))
                .unwrap();
            ws.send(Message::text(r#"{"type":"exit","code":0}"#))
                .unwrap();
        });

        let url = format!("ws://127.0.0.1:{port}");
        let mut client = HandoverClient::connect(&url).unwrap();
        client
            .send(&Inbound::LoadContext {
                context: Context {
                    regs: Regs::default(),
                    regions: vec![],
                },
                mode: Mode::Host,
            })
            .unwrap();
        let events = client.recv_until_session_end().unwrap();
        assert_eq!(
            events,
            vec![Outbound::Stdout(b"Hi".to_vec()), Outbound::Exit(0)],
        );
    }

    #[test]
    fn client_handles_pause_then_paused_round_trip() {
        // The headline handoff flow: client sends LoadContext, then
        // Pause; server emits a Paused carrying back a Context the
        // client can in principle hand to another engine.
        let port = spawn_mock_server(|ws| {
            let _load = ws.read().expect("read load_context");
            let pause = ws.read().expect("read pause").into_text().unwrap();
            assert_eq!(pause, r#"{"type":"pause"}"#);
            ws.send(Message::text(
                r#"{"type":"paused","regs":{"eax":7,"ebx":0,"ecx":0,"edx":0,"esi":0,"edi":0,"ebp":0,"esp":0,"eip":4096,"eflags":0},"regions":[{"addr":4096,"bytes":"yv4="}],"signal":19,"reason":"pause"}"#,
            ))
            .unwrap();
        });

        let url = format!("ws://127.0.0.1:{port}");
        let mut client = HandoverClient::connect(&url).unwrap();
        client
            .send(&Inbound::LoadContext {
                context: Context {
                    regs: Regs::default(),
                    regions: vec![],
                },
                mode: Mode::Host,
            })
            .unwrap();
        client.send(&Inbound::Pause).unwrap();
        let events = client.recv_until_session_end().unwrap();
        assert_eq!(events.len(), 1);
        match &events[0] {
            Outbound::Paused {
                regs,
                regions,
                signal,
                ..
            } => {
                assert_eq!(regs.eax, 7);
                assert_eq!(regs.eip, 4096);
                assert_eq!(*signal, 19);
                assert_eq!(regions.len(), 1);
                assert_eq!(regions[0].addr, 4096);
                assert_eq!(regions[0].bytes, vec![0xca, 0xfe]);
            }
            other => panic!("expected Paused, got {other:?}"),
        }
    }
}
