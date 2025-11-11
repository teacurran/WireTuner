//! Job models and state management for PDF export queue.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;
use uuid::Uuid;

/// PDF export job request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdfExportJob {
    pub job_id: String,
    pub document_id: String,
    pub svg_content: String,
    pub output_path: String,
    pub metadata: JobMetadata,
    pub status: JobStatus,
    pub retry_count: u8,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JobMetadata {
    pub artboard_ids: Vec<String>,
    pub export_scope: String,
    pub client_version: String,
    pub user_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum JobStatus {
    Queued,
    Processing,
    Complete,
    Failed,
}

impl fmt::Display for JobStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            JobStatus::Queued => write!(f, "queued"),
            JobStatus::Processing => write!(f, "processing"),
            JobStatus::Complete => write!(f, "complete"),
            JobStatus::Failed => write!(f, "failed"),
        }
    }
}

impl PdfExportJob {
    pub fn new(document_id: String, svg_content: String, output_path: String, metadata: JobMetadata) -> Self {
        let now = Utc::now();
        Self {
            job_id: Uuid::new_v4().to_string(),
            document_id,
            svg_content,
            output_path,
            metadata,
            status: JobStatus::Queued,
            retry_count: 0,
            created_at: now,
            updated_at: now,
            error: None,
        }
    }

    pub fn start_processing(&mut self) {
        self.status = JobStatus::Processing;
        self.updated_at = Utc::now();
    }

    pub fn mark_complete(&mut self) {
        self.status = JobStatus::Complete;
        self.updated_at = Utc::now();
        self.error = None;
    }

    pub fn mark_failed(&mut self, error: String) {
        self.status = JobStatus::Failed;
        self.updated_at = Utc::now();
        self.error = Some(error);
    }

    pub fn retry(&mut self) -> bool {
        const MAX_RETRIES: u8 = 3;
        if self.retry_count < MAX_RETRIES {
            self.retry_count += 1;
            self.status = JobStatus::Queued;
            self.updated_at = Utc::now();
            true
        } else {
            self.mark_failed("Max retries exceeded".to_string());
            false
        }
    }

    pub fn processing_duration_ms(&self) -> Option<i64> {
        if self.status == JobStatus::Complete || self.status == JobStatus::Failed {
            Some(self.updated_at.signed_duration_since(self.created_at).num_milliseconds())
        } else {
            None
        }
    }
}
