//! Redis-based job queue for PDF export tasks.

use crate::job::PdfExportJob;
use anyhow::{Context, Result};
use redis::{aio::ConnectionManager, AsyncCommands};
use serde_json;
use tracing::{debug, error, info};

/// Queue name for PDF export jobs.
const QUEUE_KEY: &str = "wiretuner:export:pdf:queue";

/// Status key prefix for job status tracking.
const STATUS_KEY_PREFIX: &str = "wiretuner:export:pdf:status";

/// Job TTL in seconds (24 hours).
const JOB_TTL_SECONDS: u64 = 86400;

/// Redis-based job queue manager.
///
/// Provides async job enqueue/dequeue operations with job status tracking.
/// Jobs are stored as JSON in Redis lists, with separate status keys for
/// client polling.
pub struct JobQueue {
    /// Redis connection manager for async operations.
    pub conn: ConnectionManager,
}

impl JobQueue {
    /// Creates a new job queue with the given Redis connection.
    pub fn new(conn: ConnectionManager) -> Self {
        Self { conn }
    }

    /// Enqueues a new PDF export job.
    ///
    /// The job is added to the Redis list and a status key is created
    /// for client polling. The status key expires after 24 hours.
    ///
    /// # Arguments
    ///
    /// * `job` - The PDF export job to enqueue
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success, or an error if Redis operations fail.
    pub async fn enqueue(&mut self, job: &PdfExportJob) -> Result<()> {
        let job_json = serde_json::to_string(job)
            .context("Failed to serialize job")?;

        // Push to queue (RPUSH for FIFO order)
        self.conn
            .rpush::<_, _, ()>(QUEUE_KEY, &job_json)
            .await
            .context("Failed to push job to queue")?;

        // Set status key with TTL
        let status_key = format!("{}:{}", STATUS_KEY_PREFIX, job.job_id);
        self.conn
            .set_ex::<_, _, ()>(&status_key, &job_json, JOB_TTL_SECONDS)
            .await
            .context("Failed to set job status")?;

        info!(
            "Enqueued job: job_id={}, document_id={}",
            job.job_id, job.document_id
        );

        Ok(())
    }

    /// Dequeues the next job from the queue (blocking with timeout).
    ///
    /// Uses BLPOP to wait for jobs with a 5-second timeout. Returns `None`
    /// if no jobs are available within the timeout window.
    ///
    /// # Returns
    ///
    /// Returns `Ok(Some(job))` if a job was dequeued, `Ok(None)` if timeout,
    /// or an error if Redis operations fail.
    pub async fn dequeue(&mut self) -> Result<Option<PdfExportJob>> {
        // BLPOP with 5-second timeout
        let result: Option<(String, String)> = self.conn
            .blpop(QUEUE_KEY, 5.0)
            .await
            .context("Failed to pop job from queue")?;

        match result {
            Some((_key, job_json)) => {
                let job: PdfExportJob = serde_json::from_str(&job_json)
                    .context("Failed to deserialize job")?;

                debug!("Dequeued job: job_id={}", job.job_id);
                Ok(Some(job))
            }
            None => {
                // Timeout, no job available
                Ok(None)
            }
        }
    }

    /// Updates the status of a job.
    ///
    /// This writes the updated job state to the status key, which clients
    /// poll to track progress.
    ///
    /// # Arguments
    ///
    /// * `job` - The job with updated status
    pub async fn update_status(&mut self, job: &PdfExportJob) -> Result<()> {
        let status_key = format!("{}:{}", STATUS_KEY_PREFIX, job.job_id);
        let job_json = serde_json::to_string(job)
            .context("Failed to serialize job status")?;

        self.conn
            .set_ex::<_, _, ()>(&status_key, &job_json, JOB_TTL_SECONDS)
            .await
            .context("Failed to update job status")?;

        debug!("Updated job status: job_id={}, status={}", job.job_id, job.status);
        Ok(())
    }

    /// Gets the current status of a job by ID.
    ///
    /// # Arguments
    ///
    /// * `job_id` - The job ID to query
    ///
    /// # Returns
    ///
    /// Returns `Ok(Some(job))` if the job exists, `Ok(None)` if not found,
    /// or an error if Redis operations fail.
    pub async fn get_status(&mut self, job_id: &str) -> Result<Option<PdfExportJob>> {
        let status_key = format!("{}:{}", STATUS_KEY_PREFIX, job_id);

        let job_json: Option<String> = self.conn
            .get(&status_key)
            .await
            .context("Failed to get job status")?;

        match job_json {
            Some(json) => {
                let job: PdfExportJob = serde_json::from_str(&json)
                    .context("Failed to deserialize job status")?;
                Ok(Some(job))
            }
            None => Ok(None),
        }
    }

    /// Retries a failed job by re-enqueueing it.
    ///
    /// This increments the retry count and pushes the job back to the queue
    /// if retries are available.
    ///
    /// # Arguments
    ///
    /// * `job` - The job to retry
    ///
    /// # Returns
    ///
    /// Returns `Ok(true)` if retry was enqueued, `Ok(false)` if max retries
    /// exceeded, or an error if operations fail.
    pub async fn retry_job(&mut self, mut job: PdfExportJob) -> Result<bool> {
        if job.retry() {
            self.enqueue(&job).await?;
            Ok(true)
        } else {
            // Max retries exceeded, update status to failed
            self.update_status(&job).await?;
            error!(
                "Job failed after max retries: job_id={}, error={:?}",
                job.job_id, job.error
            );
            Ok(false)
        }
    }

    /// Returns the current queue length.
    pub async fn queue_length(&mut self) -> Result<usize> {
        let len: usize = self.conn
            .llen(QUEUE_KEY)
            .await
            .context("Failed to get queue length")?;
        Ok(len)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::job::JobMetadata;

    // Note: These tests require a running Redis instance.
    // Run with: docker run -d -p 6379:6379 redis:7-alpine
    // Skip in CI: cargo test --lib -- --skip queue::tests

    #[tokio::test]
    #[ignore]
    async fn test_enqueue_dequeue() {
        let client = redis::Client::open("redis://127.0.0.1/").unwrap();
        let conn = ConnectionManager::new(client).await.unwrap();
        let mut queue = JobQueue::new(conn);

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

        // Enqueue
        queue.enqueue(&job).await.unwrap();

        // Dequeue
        let dequeued = queue.dequeue().await.unwrap();
        assert!(dequeued.is_some());

        let dequeued_job = dequeued.unwrap();
        assert_eq!(dequeued_job.job_id, job.job_id);
        assert_eq!(dequeued_job.status, JobStatus::Queued);
    }

    #[tokio::test]
    #[ignore]
    async fn test_status_tracking() {
        let client = redis::Client::open("redis://127.0.0.1/").unwrap();
        let conn = ConnectionManager::new(client).await.unwrap();
        let mut queue = JobQueue::new(conn);

        let mut job = PdfExportJob::new(
            "doc-456".to_string(),
            "<svg></svg>".to_string(),
            "/tmp/test2.pdf".to_string(),
            JobMetadata {
                artboard_ids: vec![],
                export_scope: "all".to_string(),
                client_version: "0.1.0".to_string(),
                user_id: None,
            },
        );

        // Enqueue
        queue.enqueue(&job).await.unwrap();

        // Get status
        let status = queue.get_status(&job.job_id).await.unwrap();
        assert!(status.is_some());
        assert_eq!(status.unwrap().status, JobStatus::Queued);

        // Update status
        job.start_processing();
        queue.update_status(&job).await.unwrap();

        // Verify update
        let updated_status = queue.get_status(&job.job_id).await.unwrap();
        assert_eq!(updated_status.unwrap().status, JobStatus::Processing);
    }
}
