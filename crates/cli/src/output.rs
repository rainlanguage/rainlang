use std::io::Write;
use std::path::PathBuf;

/// Output encoding formats supported by the CLI.
#[derive(clap::ValueEnum, Clone)]
pub enum SupportedOutputEncoding {
    /// Raw binary bytes.
    Binary,
    /// 0x-prefixed hex string.
    Hex,
}

/// Writes `bytes` to `output_path` (or stdout) using the given encoding.
pub fn output(
    output_path: &Option<PathBuf>,
    output_encoding: SupportedOutputEncoding,
    bytes: &[u8],
) -> anyhow::Result<()> {
    let hex_encoded: String;
    let encoded_bytes: &[u8] = match output_encoding {
        SupportedOutputEncoding::Binary => bytes,
        SupportedOutputEncoding::Hex => {
            hex_encoded = alloy::primitives::hex::encode_prefixed(bytes);
            hex_encoded.as_bytes()
        }
    };
    if let Some(output_path) = output_path {
        std::fs::write(output_path, encoded_bytes)?
    } else {
        std::io::stdout().write_all(encoded_bytes)?
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_output_binary_to_file() {
        let file = NamedTempFile::new().unwrap();
        let path = file.path().to_path_buf();
        let data = b"\x00\x01\x02\xff";
        output(&Some(path.clone()), SupportedOutputEncoding::Binary, data).unwrap();
        let written = std::fs::read(&path).unwrap();
        assert_eq!(written, data);
    }

    #[test]
    fn test_output_hex_to_file() {
        let file = NamedTempFile::new().unwrap();
        let path = file.path().to_path_buf();
        let data = b"\xde\xad\xbe\xef";
        output(&Some(path.clone()), SupportedOutputEncoding::Hex, data).unwrap();
        let written = std::fs::read_to_string(&path).unwrap();
        assert_eq!(written, "0xdeadbeef");
    }

    #[test]
    fn test_output_hex_empty_to_file() {
        let file = NamedTempFile::new().unwrap();
        let path = file.path().to_path_buf();
        output(&Some(path.clone()), SupportedOutputEncoding::Hex, b"").unwrap();
        let written = std::fs::read_to_string(&path).unwrap();
        assert_eq!(written, "0x");
    }

    #[test]
    fn test_output_binary_to_stdout() {
        output(&None, SupportedOutputEncoding::Binary, b"hello").unwrap();
    }

    #[test]
    fn test_output_hex_to_stdout() {
        output(&None, SupportedOutputEncoding::Hex, b"\xca\xfe").unwrap();
    }
}
