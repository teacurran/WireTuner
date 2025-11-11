//! WireTuner PDF Export Worker Library
//!
//! This library provides the core functionality for the PDF export worker service.
//! It exposes modules for job management, queue operations, SVG conversion, and telemetry.
//!
//! ## Module Overview
//!
//! - `converter`: SVG to PDF conversion using resvg
//! - `job`: Job models and state management
//! - `queue`: Redis-based job queue operations
//! - `telemetry`: OpenTelemetry integration and structured logging
//!
//! ## Example Usage
//!
//! ```rust,no_run
//! use worker_export::{
//!     converter::SvgToPdfConverter,
//!     job::{PdfExportJob, JobMetadata},
//!     queue::JobQueue,
//! };
//!
//! #[tokio::main]
//! async fn main() {
//!     // Create converter
//!     let converter = SvgToPdfConverter::new();
//!
//!     // Create job
//!     let job = PdfExportJob::new(
//!         "doc-123".to_string(),
//!         "<svg></svg>".to_string(),
//!         "/tmp/output.pdf".to_string(),
//!         JobMetadata {
//!             artboard_ids: vec!["ab-1".to_string()],
//!             export_scope: "current".to_string(),
//!             client_version: "0.1.0".to_string(),
//!             user_id: None,
//!         },
//!     );
//!
//!     // Convert SVG to PDF
//!     let result = converter.convert(&job.svg_content, &job.output_path);
//!     assert!(result.is_ok());
//! }
//! ```

pub mod converter;
pub mod job;
pub mod queue;
pub mod telemetry;
