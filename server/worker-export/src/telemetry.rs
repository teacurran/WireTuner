//! Telemetry and structured logging for export worker.

use crate::job::{PdfExportJob, JobStatus};
use opentelemetry::trace::{Span, Tracer};
use opentelemetry::{global, KeyValue};
use tracing::{info, warn};

/// Records telemetry for a completed or failed job.
///
/// This function emits structured logs and OpenTelemetry spans for monitoring
/// export pipeline health. Metrics include:
/// - Job duration (ms)
/// - Success/failure status
/// - Retry count
/// - Error messages (if failed)
///
/// # Arguments
///
/// * `job` - The completed or failed job
pub fn record_job_telemetry(job: &PdfExportJob) {
    let tracer = global::tracer("pdf-export-worker");
    let mut span = tracer.start("pdf_export_job");

    // Add span attributes
    span.set_attribute(KeyValue::new("job_id", job.job_id.clone()));
    span.set_attribute(KeyValue::new("document_id", job.document_id.clone()));
    span.set_attribute(KeyValue::new("status", job.status.to_string()));
    span.set_attribute(KeyValue::new("retry_count", job.retry_count as i64));

    if let Some(duration_ms) = job.processing_duration_ms() {
        span.set_attribute(KeyValue::new("duration_ms", duration_ms));

        // Log performance metrics
        info!(
            job_id = %job.job_id,
            document_id = %job.document_id,
            duration_ms = duration_ms,
            status = %job.status,
            "PDF export job completed"
        );

        // Warn if exceeding performance threshold (5 seconds)
        if duration_ms > 5000 {
            warn!(
                job_id = %job.job_id,
                duration_ms = duration_ms,
                "PDF export exceeded performance threshold (5000ms)"
            );
        }
    }

    // Record error details if job failed
    if job.status == JobStatus::Failed {
        if let Some(ref error) = job.error {
            span.set_attribute(KeyValue::new("error", error.clone()));
            warn!(
                job_id = %job.job_id,
                error = %error,
                retry_count = job.retry_count,
                "PDF export job failed"
            );
        }
    }

    // Record metadata
    span.set_attribute(KeyValue::new(
        "export_scope",
        job.metadata.export_scope.clone(),
    ));
    span.set_attribute(KeyValue::new(
        "artboard_count",
        job.metadata.artboard_ids.len() as i64,
    ));
    span.set_attribute(KeyValue::new(
        "client_version",
        job.metadata.client_version.clone(),
    ));

    span.end();
}

/// Records a worker heartbeat for monitoring worker health.
///
/// This should be called periodically by the worker loop to signal
/// that the worker is alive and processing jobs.
///
/// # Arguments
///
/// * `queue_length` - Current number of jobs in the queue
pub fn record_worker_heartbeat(queue_length: usize) {
    let tracer = global::tracer("pdf-export-worker");
    let mut span = tracer.start("worker_heartbeat");

    span.set_attribute(KeyValue::new("queue_length", queue_length as i64));
    span.end();

    info!(
        queue_length = queue_length,
        "Worker heartbeat"
    );
}

/// Initializes OpenTelemetry with OTLP exporter.
///
/// This should be called once at worker startup. Reads configuration
/// from environment variables:
/// - `OTEL_EXPORTER_OTLP_ENDPOINT` - Collector endpoint (default: http://localhost:4317)
/// - `OTEL_SERVICE_NAME` - Service name (default: pdf-export-worker)
///
/// # Returns
///
/// Returns `Ok(())` on success, or an error if initialization fails.
pub fn init_telemetry() -> Result<(), Box<dyn std::error::Error>> {
    use opentelemetry_otlp::WithExportConfig;
    use opentelemetry_sdk::trace::Config;

    let endpoint = std::env::var("OTEL_EXPORTER_OTLP_ENDPOINT")
        .unwrap_or_else(|_| "http://localhost:4317".to_string());

    let service_name = std::env::var("OTEL_SERVICE_NAME")
        .unwrap_or_else(|_| "pdf-export-worker".to_string());

    // Initialize OTLP exporter
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint(&endpoint),
        )
        .with_trace_config(Config::default().with_resource(
            opentelemetry_sdk::Resource::new(vec![
                KeyValue::new("service.name", service_name),
                KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
            ]),
        ))
        .install_batch(opentelemetry_sdk::runtime::Tokio)?;

    global::set_tracer_provider(tracer.provider().unwrap());

    info!("Telemetry initialized: endpoint={}", endpoint);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::job::JobMetadata;

    #[test]
    fn test_record_job_telemetry() {
        // Initialize no-op telemetry for testing
        let _ = init_telemetry();

        let mut job = PdfExportJob::new(
            "doc-123".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/test.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec!["ab-1".to_string()],
                export_scope: "current".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        job.mark_complete();

        // Should not panic
        record_job_telemetry(&job);
    }

    #[test]
    fn test_record_failed_job() {
        let _ = init_telemetry();

        let mut job = PdfExportJob::new(
            "doc-456".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/test.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec![],
                export_scope: "all".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        job.mark_failed("Test error".to_string());

        // Should not panic and should log error
        record_job_telemetry(&job);
    }
}
