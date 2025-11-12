//! SVG to PDF conversion with TRUE vector fidelity via svg2pdf.

use anyhow::{Context, Result};
use std::fs;
use tracing::info;

/// SVG to PDF converter using svg2pdf for true vector fidelity.
///
/// This converter uses the svg2pdf crate which converts SVG to PDF
/// maintaining complete vector graphics (no rasterization).
pub struct SvgToPdfConverter;

impl SvgToPdfConverter {
    /// Creates a new converter with default options.
    pub fn new() -> Self {
        Self
    }

    /// Converts SVG content to PDF and writes to the specified output path.
    ///
    /// # Arguments
    ///
    /// * `svg_content` - UTF-8 SVG XML string
    /// * `output_path` - Filesystem path for PDF output
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success, or an error if parsing or rendering fails.
    ///
    /// # Errors
    ///
    /// - SVG parsing errors (malformed XML, unsupported features)
    /// - File I/O errors (permissions, disk full)
    /// - Rendering errors (out of memory, invalid dimensions)
    pub fn convert(&self, svg_content: &str, output_path: &str) -> Result<()> {
        info!("Converting SVG to PDF (VECTOR): output={}", output_path);

        // Parse SVG to usvg tree
        let tree = usvg::Tree::from_str(svg_content, &usvg::Options::default())
            .context("Failed to parse SVG content")?;

        // Validate tree has valid dimensions
        let size = tree.size();
        if size.width() <= 0.0 || size.height() <= 0.0 {
            anyhow::bail!(
                "Invalid SVG dimensions: {}x{}",
                size.width(),
                size.height()
            );
        }

        info!(
            "SVG parsed successfully: {}x{} units",
            size.width(),
            size.height()
        );

        // Convert to PDF using svg2pdf (true vector conversion)
        let pdf_data = svg2pdf::to_pdf(
            &tree,
            svg2pdf::ConversionOptions::default(),
            svg2pdf::PageOptions::default()
        );

        // Write PDF to file
        fs::write(output_path, &pdf_data)
            .with_context(|| format!("Failed to write PDF to {}", output_path))?;

        info!("PDF export complete (VECTOR): {} bytes", pdf_data.len());
        Ok(())
    }

}

impl Default for SvgToPdfConverter {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_convert_simple_svg() {
        let converter = SvgToPdfConverter::new();
        let svg = r#"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>"#;

        let temp = NamedTempFile::new().unwrap();
        let result = converter.convert(svg, temp.path().to_str().unwrap());

        assert!(result.is_ok());
        assert!(temp.path().exists());

        // Verify PDF is not empty
        let metadata = temp.as_file().metadata().unwrap();
        assert!(metadata.len() > 0);
    }

    #[test]
    fn test_invalid_svg() {
        let converter = SvgToPdfConverter::new();
        let invalid_svg = "not an svg";

        let temp = NamedTempFile::new().unwrap();
        let result = converter.convert(invalid_svg, temp.path().to_str().unwrap());

        assert!(result.is_err());
    }

    #[test]
    fn test_zero_dimensions() {
        let converter = SvgToPdfConverter::new();
        let svg = r#"<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0"></svg>"#;

        let temp = NamedTempFile::new().unwrap();
        let result = converter.convert(svg, temp.path().to_str().unwrap());

        assert!(result.is_err());
    }
}
