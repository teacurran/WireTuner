//! PDF Export Worker Service
//!
//! This worker consumes PDF export jobs from a Redis queue and processes them
//! using resvg for high-fidelity SVG-to-PDF conversion.
//!
//! ## Architecture
//!
//! - **Queue**: Redis list (`wiretuner:export:pdf:queue`)
//! - **Status**: Redis keys (`wiretuner:export:pdf:status:{job_id}`)
//! - **Converter**: resvg-based SVG→PDF pipeline
//! - **Telemetry**: OpenTelemetry OTLP export
//!
//! ## Configuration
//!
//! Environment variables:
//! - `REDIS_URL`: Redis connection string (default: redis://127.0.0.1/)
//! - `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP collector endpoint
//! - `WORKER_CONCURRENCY`: Number of concurrent workers (default: 4)
//! - `RUST_LOG`: Log level (default: info)

mod converter;
mod job;
mod queue;
mod telemetry;

use anyhow::{Context, Result};
use converter::SvgToPdfConverter;
use job::PdfExportJob;
use queue::JobQueue;
use redis::Client;
use std::sync::Arc;
use tokio::signal;
use tokio::sync::Semaphore;
use tracing::{error, info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Initialize OpenTelemetry
    if let Err(e) = telemetry::init_telemetry() {
        warn!("Failed to initialize telemetry: {}", e);
    }

    info!("Starting PDF export worker service");

    // Load configuration
    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://127.0.0.1/".to_string());
    let concurrency: usize = std::env::var("WORKER_CONCURRENCY")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(4);

    info!(
        "Configuration: redis_url={}, concurrency={}",
        redis_url, concurrency
    );

    // Connect to Redis
    let client = Client::open(redis_url.as_str())
        .context("Failed to create Redis client")?;
    let conn = redis::aio::ConnectionManager::new(client)
        .await
        .context("Failed to connect to Redis")?;

    info!("Connected to Redis");

    // Create shared resources
    let semaphore = Arc::new(Semaphore::new(concurrency));
    let converter = Arc::new(SvgToPdfConverter::new());

    // Spawn worker tasks
    let mut handles = vec![];
    for worker_id in 0..concurrency {
        let conn = conn.clone();
        let semaphore = semaphore.clone();
        let converter = converter.clone();

        let handle = tokio::spawn(async move {
            worker_loop(worker_id, conn, semaphore, converter).await
        });

        handles.push(handle);
    }

    // Wait for shutdown signal
    info!("Worker service ready, press Ctrl+C to shutdown");
    signal::ctrl_c().await.context("Failed to listen for Ctrl+C")?;

    info!("Received shutdown signal, waiting for workers to finish...");

    // Wait for all workers to complete
    for handle in handles {
        let _ = handle.await;
    }

    info!("Worker service shutdown complete");
    Ok(())
}

/// Main worker loop that processes jobs from the queue.
///
/// This function runs indefinitely until the process is terminated.
/// It uses a semaphore to limit concurrent job processing.
async fn worker_loop(
    worker_id: usize,
    conn: redis::aio::ConnectionManager,
    semaphore: Arc<Semaphore>,
    converter: Arc<SvgToPdfConverter>,
) {
    let mut queue = JobQueue::new(conn);

    info!("Worker {} started", worker_id);

    loop {
        // Dequeue next job (blocks with timeout)
        let job = match queue.dequeue().await {
            Ok(Some(job)) => job,
            Ok(None) => {
                // Timeout, no job available
                continue;
            }
            Err(e) => {
                error!("Worker {} failed to dequeue job: {}", worker_id, e);
                tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                continue;
            }
        };

        // Acquire semaphore permit
        let permit = semaphore.clone().acquire_owned().await.unwrap();

        // Spawn job processing task
        let mut queue_clone = JobQueue::new(queue.conn.clone());
        let converter = converter.clone();

        tokio::spawn(async move {
            process_job(job, &mut queue_clone, &converter).await;
            drop(permit); // Release semaphore
        });

        // Record heartbeat every 10 jobs
        if let Ok(queue_len) = queue.queue_length().await {
            if queue_len % 10 == 0 {
                telemetry::record_worker_heartbeat(queue_len);
            }
        }
    }
}

/// Processes a single PDF export job.
///
/// This function handles the complete job lifecycle:
/// 1. Mark job as processing
/// 2. Convert SVG to PDF
/// 3. Mark job as complete or failed
/// 4. Record telemetry
/// 5. Retry on failure (up to 3 times)
async fn process_job(
    mut job: PdfExportJob,
    queue: &mut JobQueue,
    converter: &SvgToPdfConverter,
) {
    info!(
        "Processing job: job_id={}, document_id={}",
        job.job_id, job.document_id
    );

    // Mark as processing
    job.start_processing();
    if let Err(e) = queue.update_status(&job).await {
        error!("Failed to update job status: {}", e);
    }

    // Convert SVG to PDF
    let result = converter.convert(&job.svg_content, &job.output_path);

    match result {
        Ok(()) => {
            // Mark as complete
            job.mark_complete();
            if let Err(e) = queue.update_status(&job).await {
                error!("Failed to update job status: {}", e);
            }

            info!(
                "Job completed: job_id={}, duration_ms={:?}",
                job.job_id,
                job.processing_duration_ms()
            );
        }
        Err(e) => {
            // Mark as failed
            let error_msg = format!("{:#}", e);
            error!(
                "Job failed: job_id={}, error={}",
                job.job_id, error_msg
            );

            job.mark_failed(error_msg);

            // Attempt retry
            match queue.retry_job(job.clone()).await {
                Ok(true) => {
                    info!(
                        "Job re-queued for retry: job_id={}, retry_count={}",
                        job.job_id, job.retry_count
                    );
                }
                Ok(false) => {
                    warn!(
                        "Job failed permanently: job_id={}, max retries exceeded",
                        job.job_id
                    );
                }
                Err(e) => {
                    error!("Failed to retry job: {}", e);
                }
            }
        }
    }

    // Record telemetry
    telemetry::record_job_telemetry(&job);
}
