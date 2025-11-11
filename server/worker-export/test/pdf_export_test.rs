/// Integration tests for PDF export worker.
///
/// These tests verify the complete export pipeline from job enqueue
/// through SVG conversion to PDF output.
///
/// ## Running Tests
///
/// ```bash
/// # Unit tests (no external dependencies)
/// cargo test --lib
///
/// # Integration tests (requires Redis)
/// docker run -d -p 6379:6379 redis:7-alpine
/// cargo test --test pdf_export_test
/// ```

#[cfg(test)]
mod tests {
    use worker_export::{
        converter::SvgToPdfConverter,
        job::{JobMetadata, PdfExportJob},
        queue::JobQueue,
    };
    use redis::Client;
    use tempfile::NamedTempFile;

    /// Test SVG to PDF conversion with valid input.
    #[test]
    fn test_svg_to_pdf_conversion() {
        let converter = SvgToPdfConverter::new();

        let svg = r#"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
            <rect x="10" y="10" width="180" height="180" fill="blue"/>
            <circle cx="100" cy="100" r="50" fill="red"/>
        </svg>"#;

        let temp = NamedTempFile::new().unwrap();
        let result = converter.convert(svg, temp.path().to_str().unwrap());

        assert!(result.is_ok(), "Conversion should succeed");
        assert!(temp.path().exists(), "PDF file should exist");

        // Verify file has content
        let metadata = std::fs::metadata(temp.path()).unwrap();
        assert!(metadata.len() > 0, "PDF should have content");
    }

    /// Test conversion failure with invalid SVG.
    #[test]
    fn test_invalid_svg_conversion() {
        let converter = SvgToPdfConverter::new();
        let invalid_svg = "<not>valid</svg>";

        let temp = NamedTempFile::new().unwrap();
        let result = converter.convert(invalid_svg, temp.path().to_str().unwrap());

        assert!(result.is_err(), "Invalid SVG should fail");
    }

    /// Test job creation with defaults.
    #[test]
    fn test_job_creation() {
        let job = PdfExportJob::new(
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

        assert_eq!(job.status, worker_export::job::JobStatus::Queued);
        assert_eq!(job.retry_count, 0);
        assert!(job.error.is_none());
    }

    /// Test job state transitions.
    #[test]
    fn test_job_state_transitions() {
        let mut job = PdfExportJob::new(
            "doc-123".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/test.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec![],
                export_scope: "all".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        // Queued → Processing
        job.start_processing();
        assert_eq!(job.status, worker_export::job::JobStatus::Processing);

        // Processing → Complete
        job.mark_complete();
        assert_eq!(job.status, worker_export::job::JobStatus::Complete);
        assert!(job.processing_duration_ms().is_some());
    }

    /// Test retry logic with max retries.
    #[test]
    fn test_retry_logic() {
        let mut job = PdfExportJob::new(
            "doc-123".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/test.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec![],
                export_scope: "all".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        // Retries 1-3 should succeed
        assert!(job.retry());
        assert_eq!(job.retry_count, 1);
        assert!(job.retry());
        assert_eq!(job.retry_count, 2);
        assert!(job.retry());
        assert_eq!(job.retry_count, 3);

        // 4th retry should fail
        assert!(!job.retry());
        assert_eq!(job.status, worker_export::job::JobStatus::Failed);
    }

    /// Integration test: Enqueue and dequeue job.
    ///
    /// Requires Redis running on localhost:6379.
    #[tokio::test]
    #[ignore]
    async fn test_queue_integration() {
        let client = Client::open("redis://127.0.0.1/").unwrap();
        let conn = redis::aio::ConnectionManager::new(client).await.unwrap();
        let mut queue = JobQueue::new(conn);

        let job = PdfExportJob::new(
            "doc-integration".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/integration.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec!["ab-1".to_string()],
                export_scope: "current".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        // Enqueue
        queue.enqueue(&job).await.unwrap();

        // Dequeue
        let dequeued = queue.dequeue().await.unwrap();
        assert!(dequeued.is_some());

        let dequeued_job = dequeued.unwrap();
        assert_eq!(dequeued_job.job_id, job.job_id);
        assert_eq!(dequeued_job.document_id, "doc-integration");
    }

    /// Integration test: Job status tracking.
    ///
    /// Requires Redis running on localhost:6379.
    #[tokio::test]
    #[ignore]
    async fn test_status_tracking() {
        let client = Client::open("redis://127.0.0.1/").unwrap();
        let conn = redis::aio::ConnectionManager::new(client).await.unwrap();
        let mut queue = JobQueue::new(conn);

        let mut job = PdfExportJob::new(
            "doc-status".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/status.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec![],
                export_scope: "all".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        // Enqueue
        queue.enqueue(&job).await.unwrap();

        // Get initial status
        let status = queue.get_status(&job.job_id).await.unwrap();
        assert!(status.is_some());
        assert_eq!(status.unwrap().status, worker_export::job::JobStatus::Queued);

        // Update status
        job.start_processing();
        queue.update_status(&job).await.unwrap();

        // Verify update
        let updated = queue.get_status(&job.job_id).await.unwrap();
        assert_eq!(
            updated.unwrap().status,
            worker_export::job::JobStatus::Processing
        );
    }
}
