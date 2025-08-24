#!/bin/bash

# CycleAvatar Database Backup Script

set -e

# Configuration
DB_NAME="cycleavatar_prod"
DB_USER="cycleavatar_user"
DB_HOST="db"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="cycleavatar_backup_${DATE}.sql"
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

echo "Starting database backup at $(date)"

# Create database backup
pg_dump -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} --no-password > ${BACKUP_DIR}/${BACKUP_FILE}

# Compress backup
gzip ${BACKUP_DIR}/${BACKUP_FILE}
BACKUP_FILE="${BACKUP_FILE}.gz"

echo "Backup created: ${BACKUP_FILE}"

# Upload to S3 (if configured)
if [ ! -z "$BACKUP_S3_BUCKET" ]; then
    echo "Uploading backup to S3..."
    aws s3 cp ${BACKUP_DIR}/${BACKUP_FILE} s3://${BACKUP_S3_BUCKET}/database/${BACKUP_FILE}
    echo "Backup uploaded to S3"
fi

# Clean up old backups
echo "Cleaning up old backups..."
find ${BACKUP_DIR} -name "cycleavatar_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

# Clean up old S3 backups (if configured)
if [ ! -z "$BACKUP_S3_BUCKET" ]; then
    aws s3 ls s3://${BACKUP_S3_BUCKET}/database/ | while read -r line; do
        createDate=$(echo $line | awk '{print $1" "$2}')
        createDate=$(date -d "$createDate" +%s)
        olderThan=$(date -d "${RETENTION_DAYS} days ago" +%s)
        if [[ $createDate -lt $olderThan ]]; then
            fileName=$(echo $line | awk '{print $4}')
            if [[ $fileName != "" ]]; then
                aws s3 rm s3://${BACKUP_S3_BUCKET}/database/$fileName
                echo "Deleted old S3 backup: $fileName"
            fi
        fi
    done
fi

echo "Database backup completed at $(date)"

# Send notification (if configured)
if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ CycleAvatar database backup completed successfully: ${BACKUP_FILE}\"}" \
        $SLACK_WEBHOOK_URL
fi