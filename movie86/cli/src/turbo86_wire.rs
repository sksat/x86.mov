//! Rust mirror of turbo86's `proto.Inbound` / `proto.Outbound` types.
//!
//! Engine-handoff transport: when movie86-cli's `handover` subcommand
//! drives turbo86 over WebSocket, both sides exchange JSON frames
//! carrying these variants. The schema must match `proto/proto.go`
//! byte-for-byte (lowercase type tags, lowercase field names, base64
//! `bytes`). Drift here breaks the handoff silently — keep both
//! sides golden-tested.
//!
//! What's modelled here is the strict subset movie86-cli needs:
//! - Inbound: `LoadContext`, `Stop`, `Pause` (the messages the client
//!   sends to turbo86). `Code` and `Start` are turbo86-only entry
//!   points; the handover flow uses `LoadContext` exclusively.
//! - Outbound: every variant turbo86 can emit (`Stdout`, `Stderr`,
//!   `Exit`, `Fault`, `Paused`) — the client must understand all of
//!   them since any can end a session.

use base64::engine::general_purpose::STANDARD as B64_STANDARD;
use base64::Engine;
use serde::{Deserialize, Serialize};

use movie86::{Context, MemRegion, Regs};

/// Mirrors `proto.Mode`. Empty = default host on the Go side; we
/// always emit explicit values to avoid implicit drift.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Host,
    Trap,
}

impl Mode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Host => "host",
            Self::Trap => "trap",
        }
    }
}

/// One Inbound message — Rust mirror of `proto.Inbound`. Only the
/// variants the handover flow uses are modelled; `Code` and `Start`
/// stay on the Go side.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Inbound {
    LoadContext { context: Context, mode: Mode },
    Stop,
    Pause,
}

/// One Outbound event — Rust mirror of `proto.Outbound`. All
/// variants are modelled because any of them can terminate a
/// session and the handover client must route them all.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outbound {
    Stdout(Vec<u8>),
    Stderr(Vec<u8>),
    Exit(i32),
    Fault(String),
    Paused {
        regs: Regs,
        regions: Vec<MemRegion>,
        signal: u8,
        reason: String,
    },
}

// --- Wire structs (private, serde-derived).
// Lowercase field names + lowercase "type" discriminator match
// Go's `encoding/json` output exactly.

#[derive(Debug, Serialize, Deserialize)]
struct WireRegs {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
    esi: u32,
    edi: u32,
    ebp: u32,
    esp: u32,
    eip: u32,
    eflags: u32,
}

impl From<&Regs> for WireRegs {
    fn from(r: &Regs) -> Self {
        Self {
            eax: r.eax,
            ebx: r.ebx,
            ecx: r.ecx,
            edx: r.edx,
            esi: r.esi,
            edi: r.edi,
            ebp: r.ebp,
            esp: r.esp,
            eip: r.eip,
            eflags: r.eflags,
        }
    }
}

impl From<WireRegs> for Regs {
    fn from(w: WireRegs) -> Self {
        Self {
            eax: w.eax,
            ebx: w.ebx,
            ecx: w.ecx,
            edx: w.edx,
            esi: w.esi,
            edi: w.edi,
            ebp: w.ebp,
            esp: w.esp,
            eip: w.eip,
            eflags: w.eflags,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct WireRegion {
    addr: u32,
    #[serde(with = "b64_bytes")]
    bytes: Vec<u8>,
}

impl From<&MemRegion> for WireRegion {
    fn from(r: &MemRegion) -> Self {
        Self {
            addr: r.addr,
            bytes: r.bytes.clone(),
        }
    }
}

impl From<WireRegion> for MemRegion {
    fn from(w: WireRegion) -> Self {
        Self {
            addr: w.addr,
            bytes: w.bytes,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct WireContext {
    regs: WireRegs,
    regions: Vec<WireRegion>,
}

impl From<&Context> for WireContext {
    fn from(c: &Context) -> Self {
        Self {
            regs: WireRegs::from(&c.regs),
            regions: c.regions.iter().map(WireRegion::from).collect(),
        }
    }
}

impl From<WireContext> for Context {
    fn from(w: WireContext) -> Self {
        Self {
            regs: w.regs.into(),
            regions: w.regions.into_iter().map(MemRegion::from).collect(),
        }
    }
}

#[derive(Debug, Serialize)]
struct WireInboundLoadContext<'a> {
    #[serde(rename = "type")]
    ty: &'static str,
    context: WireContext,
    mode: &'a str,
}

#[derive(Debug, Serialize)]
struct WireInboundBare {
    #[serde(rename = "type")]
    ty: &'static str,
}

mod b64_bytes {
    use super::{Engine, B64_STANDARD};
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(v: &[u8], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&B64_STANDARD.encode(v))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<u8>, D::Error> {
        let s = String::deserialize(d)?;
        B64_STANDARD.decode(s).map_err(serde::de::Error::custom)
    }
}

/// Encode an [`Inbound`] as the JSON frame turbo86 expects.
///
/// # Errors
///
/// Returns [`serde_json::Error`] only on writer failure (not
/// reachable for the in-memory `to_vec` path used here).
pub fn marshal_inbound(msg: &Inbound) -> Result<Vec<u8>, serde_json::Error> {
    match msg {
        Inbound::LoadContext { context, mode } => serde_json::to_vec(&WireInboundLoadContext {
            ty: "load_context",
            context: WireContext::from(context),
            mode: mode.as_str(),
        }),
        Inbound::Stop => serde_json::to_vec(&WireInboundBare { ty: "stop" }),
        Inbound::Pause => serde_json::to_vec(&WireInboundBare { ty: "pause" }),
    }
}

/// Decode an [`Outbound`] frame from turbo86.
///
/// # Errors
///
/// Returns [`serde_json::Error`] for malformed JSON, missing fields,
/// unknown discriminator, or bad base64 inside `bytes` / `regions`.
pub fn unmarshal_outbound(bytes: &[u8]) -> Result<Outbound, serde_json::Error> {
    // Peek the discriminator without parsing the full payload twice
    // — same shape as Go's UnmarshalOutbound.
    #[derive(Deserialize)]
    struct Probe<'a> {
        #[serde(rename = "type")]
        ty: &'a str,
    }
    let probe: Probe = serde_json::from_slice(bytes)?;
    match probe.ty {
        "stdout" => {
            #[derive(Deserialize)]
            struct Body {
                #[serde(with = "b64_bytes")]
                bytes: Vec<u8>,
            }
            let b: Body = serde_json::from_slice(bytes)?;
            Ok(Outbound::Stdout(b.bytes))
        }
        "stderr" => {
            #[derive(Deserialize)]
            struct Body {
                #[serde(with = "b64_bytes")]
                bytes: Vec<u8>,
            }
            let b: Body = serde_json::from_slice(bytes)?;
            Ok(Outbound::Stderr(b.bytes))
        }
        "exit" => {
            #[derive(Deserialize)]
            struct Body {
                code: i32,
            }
            let b: Body = serde_json::from_slice(bytes)?;
            Ok(Outbound::Exit(b.code))
        }
        "fault" => {
            #[derive(Deserialize)]
            struct Body {
                reason: String,
            }
            let b: Body = serde_json::from_slice(bytes)?;
            Ok(Outbound::Fault(b.reason))
        }
        "paused" => {
            #[derive(Deserialize)]
            struct Body {
                regs: WireRegs,
                #[serde(default)]
                regions: Vec<WireRegion>,
                signal: u8,
                reason: String,
            }
            let b: Body = serde_json::from_slice(bytes)?;
            Ok(Outbound::Paused {
                regs: b.regs.into(),
                regions: b.regions.into_iter().map(MemRegion::from).collect(),
                signal: b.signal,
                reason: b.reason,
            })
        }
        other => Err(serde::de::Error::custom(format!(
            "unknown outbound type {other:?}"
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use movie86::{MemRegion, Regs};

    /// Golden against the Go side: a `LoadContext` frame produced by
    /// `proto.MarshalInbound(LoadContext{...})` on turbo86 must
    /// deserialize byte-for-byte to the same Rust value we emit.
    /// The blob below was captured from the Go side and committed
    /// here so a future drift on either end fails this test loud.
    #[test]
    fn marshal_inbound_load_context_matches_turbo86_wire() {
        let msg = Inbound::LoadContext {
            context: Context {
                regs: Regs {
                    eax: 0x1111,
                    ebx: 0x2222,
                    ecx: 0x3333,
                    edx: 0x4444,
                    esi: 0x5555,
                    edi: 0x6666,
                    ebp: 0x7777,
                    esp: 0x8888,
                    eip: 0xaaaa,
                    eflags: 0,
                },
                regions: vec![
                    MemRegion {
                        addr: 0x1000,
                        bytes: vec![0xde, 0xad, 0xbe, 0xef],
                    },
                    MemRegion {
                        addr: 0x3000,
                        bytes: vec![0xca, 0xfe],
                    },
                ],
            },
            mode: Mode::Host,
        };
        let actual_bytes = marshal_inbound(&msg).unwrap();
        let actual: serde_json::Value = serde_json::from_slice(&actual_bytes).unwrap();
        let expected: serde_json::Value = serde_json::from_str(
            r#"{
              "type": "load_context",
              "context": {
                "regs": {
                  "eax": 4369, "ebx": 8738, "ecx": 13107, "edx": 17476,
                  "esi": 21845, "edi": 26214, "ebp": 30583, "esp": 34952,
                  "eip": 43690, "eflags": 0
                },
                "regions": [
                  {"addr": 4096, "bytes": "3q2+7w=="},
                  {"addr": 12288, "bytes": "yv4="}
                ]
              },
              "mode": "host"
            }"#,
        )
        .unwrap();
        assert_eq!(actual, expected);
    }

    #[test]
    fn marshal_inbound_pause_is_a_bare_type_object() {
        let bytes = marshal_inbound(&Inbound::Pause).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        let expected: serde_json::Value = serde_json::from_str(r#"{"type":"pause"}"#).unwrap();
        assert_eq!(v, expected);
    }

    #[test]
    fn marshal_inbound_stop_is_a_bare_type_object() {
        let bytes = marshal_inbound(&Inbound::Stop).unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        let expected: serde_json::Value = serde_json::from_str(r#"{"type":"stop"}"#).unwrap();
        assert_eq!(v, expected);
    }

    /// Golden against the Go side for every Outbound variant.
    #[test]
    fn unmarshal_outbound_handles_every_variant() {
        // Stdout
        let m = unmarshal_outbound(br#"{"type":"stdout","bytes":"aGVsbG8="}"#).unwrap();
        assert_eq!(m, Outbound::Stdout(b"hello".to_vec()));

        // Stderr
        let m = unmarshal_outbound(br#"{"type":"stderr","bytes":"d2FybmluZw=="}"#).unwrap();
        assert_eq!(m, Outbound::Stderr(b"warning".to_vec()));

        // Exit
        let m = unmarshal_outbound(br#"{"type":"exit","code":42}"#).unwrap();
        assert_eq!(m, Outbound::Exit(42));

        // Fault
        let m = unmarshal_outbound(br#"{"type":"fault","reason":"oops"}"#).unwrap();
        assert_eq!(m, Outbound::Fault("oops".into()));

        // Paused (with regions)
        let raw = br#"{"type":"paused","regs":{"eax":0,"ebx":0,"ecx":0,"edx":0,"esi":0,"edi":0,"ebp":0,"esp":0,"eip":2048,"eflags":0},"regions":[{"addr":4096,"bytes":"3q2+7w=="}],"signal":19,"reason":"pause"}"#;
        let m = unmarshal_outbound(raw).unwrap();
        match m {
            Outbound::Paused {
                regs,
                regions,
                signal,
                reason,
            } => {
                assert_eq!(regs.eip, 2048);
                assert_eq!(regions.len(), 1);
                assert_eq!(regions[0].addr, 4096);
                assert_eq!(regions[0].bytes, vec![0xde, 0xad, 0xbe, 0xef]);
                assert_eq!(signal, 19);
                assert_eq!(reason, "pause");
            }
            other => panic!("expected Paused, got {other:?}"),
        }

        // Paused (no regions — `omitempty` on the Go side may omit
        // the field entirely; the default-empty Vec deserializer
        // must accept that).
        let m = unmarshal_outbound(
            br#"{"type":"paused","regs":{"eax":0,"ebx":0,"ecx":0,"edx":0,"esi":0,"edi":0,"ebp":0,"esp":0,"eip":0,"eflags":0},"signal":9,"reason":"kill"}"#,
        )
        .unwrap();
        match m {
            Outbound::Paused {
                regions, signal, ..
            } => {
                assert_eq!(regions, vec![]);
                assert_eq!(signal, 9);
            }
            other => panic!("expected Paused, got {other:?}"),
        }
    }

    #[test]
    fn unmarshal_outbound_rejects_unknown_discriminator() {
        assert!(unmarshal_outbound(br#"{"type":"nonsense"}"#).is_err());
    }
}
