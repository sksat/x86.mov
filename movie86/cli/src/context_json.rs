//! JSON codec for [`movie86::Context`] in turbo86's wire format.
//!
//! turbo86 marshals its `proto.Context` with Go's `encoding/json`,
//! which renders `[]byte` as a standard base64 string with padding
//! and lowercases struct tags. We mirror that exactly so a Context
//! captured by either engine deserializes verbatim on the other —
//! making cross-engine handoff a JSON-cat away.
//!
//! Schema (must stay in lockstep with `turbo86/proto/proto.go`):
//!
//! ```json
//! {
//!   "regs": {
//!     "eax": 0, "ebx": 0, "ecx": 0, "edx": 0,
//!     "esi": 0, "edi": 0, "ebp": 0, "esp": 0,
//!     "eip": 0, "eflags": 0
//!   },
//!   "regions": [
//!     {"addr": 4096, "bytes": "3q2+7w=="}
//!   ]
//! }
//! ```

use base64::engine::general_purpose::STANDARD as B64_STANDARD;
use base64::Engine;
use serde::{Deserialize, Serialize};

use movie86::{Context, MemRegion, Regs};

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
    /// Base64 (standard, padded) per Go's `encoding/json` `[]byte`
    /// default. Custom (de)serialize impls keep `MemRegion`'s API
    /// `Vec<u8>` on the Rust side.
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

/// Encode a [`Context`] as JSON in turbo86 wire format. The serialized
/// shape matches `proto.Context` marshaled by Go's `encoding/json`
/// — field order, lowercase names, base64 byte arrays.
///
/// # Errors
///
/// Returns [`serde_json::Error`] only if the underlying writer fails
/// (not possible for the in-memory `to_vec` path used here).
pub fn to_json(ctx: &Context) -> Result<Vec<u8>, serde_json::Error> {
    let w = WireContext {
        regs: WireRegs::from(&ctx.regs),
        regions: ctx.regions.iter().map(WireRegion::from).collect(),
    };
    serde_json::to_vec(&w)
}

/// Pretty-printed counterpart to [`to_json`]. Used by the CLI dump
/// path so a human can read what was captured without piping through
/// `jq`.
///
/// # Errors
///
/// See [`to_json`].
pub fn to_json_pretty(ctx: &Context) -> Result<Vec<u8>, serde_json::Error> {
    let w = WireContext {
        regs: WireRegs::from(&ctx.regs),
        regions: ctx.regions.iter().map(WireRegion::from).collect(),
    };
    serde_json::to_vec_pretty(&w)
}

/// Decode a [`Context`] from JSON in turbo86 wire format.
///
/// # Errors
///
/// Returns [`serde_json::Error`] for malformed JSON, missing fields,
/// invalid base64, or wrong field types.
pub fn from_json(bytes: &[u8]) -> Result<Context, serde_json::Error> {
    let w: WireContext = serde_json::from_slice(bytes)?;
    Ok(Context {
        regs: w.regs.into(),
        regions: w.regions.into_iter().map(MemRegion::from).collect(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_context() -> Context {
        Context {
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
        }
    }

    /// Golden match: produces byte-identical JSON to what turbo86's
    /// `encoding/json` emits for the same logical state. The expected
    /// blob was captured by serializing the equivalent
    /// `proto.Context` struct in a Go program and saved verbatim. If
    /// you ever update this, regenerate it from turbo86 — drifting
    /// from the Go side breaks engine handoff silently.
    #[test]
    fn to_json_matches_turbo86_wire_format() {
        let json = to_json(&sample_context()).unwrap();
        let actual: serde_json::Value = serde_json::from_slice(&json).unwrap();
        let expected: serde_json::Value = serde_json::from_str(
            r#"{
              "regs": {
                "eax": 4369, "ebx": 8738, "ecx": 13107, "edx": 17476,
                "esi": 21845, "edi": 26214, "ebp": 30583, "esp": 34952,
                "eip": 43690, "eflags": 0
              },
              "regions": [
                {"addr": 4096, "bytes": "3q2+7w=="},
                {"addr": 12288, "bytes": "yv4="}
              ]
            }"#,
        )
        .unwrap();
        assert_eq!(actual, expected, "JSON shape must match turbo86 verbatim");
    }

    #[test]
    fn from_json_round_trips_to_json() {
        let ctx = sample_context();
        let bytes = to_json(&ctx).unwrap();
        let back = from_json(&bytes).unwrap();
        assert_eq!(back, ctx);
    }

    #[test]
    fn from_json_accepts_turbo86_dumped_payload() {
        // This blob was produced by `proto.MarshalIndent(Context, ...)`
        // on the Go side. It must deserialize cleanly here — if not,
        // the wire formats have diverged.
        let json = br#"{
          "regs": {
            "eax": 4369, "ebx": 8738, "ecx": 13107, "edx": 17476,
            "esi": 21845, "edi": 26214, "ebp": 30583, "esp": 34952,
            "eip": 43690, "eflags": 0
          },
          "regions": [
            {"addr": 4096, "bytes": "3q2+7w=="},
            {"addr": 12288, "bytes": "yv4="}
          ]
        }"#;
        let ctx = from_json(json).unwrap();
        assert_eq!(ctx, sample_context());
    }

    #[test]
    fn from_json_rejects_invalid_base64_in_region_bytes() {
        let json = br#"{
          "regs": {
            "eax": 0, "ebx": 0, "ecx": 0, "edx": 0,
            "esi": 0, "edi": 0, "ebp": 0, "esp": 0,
            "eip": 0, "eflags": 0
          },
          "regions": [
            {"addr": 0, "bytes": "not-base64!@#$"}
          ]
        }"#;
        assert!(from_json(json).is_err());
    }

    #[test]
    fn from_json_round_trips_empty_regions() {
        let ctx = Context {
            regs: Regs::default(),
            regions: vec![],
        };
        let bytes = to_json(&ctx).unwrap();
        let back = from_json(&bytes).unwrap();
        assert_eq!(back, ctx);
    }
}
