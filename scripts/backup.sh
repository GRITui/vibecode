#!/bin/bash
set -e

# VibeCode Backup Script
# Backs up critical project state (env, logs, db) with rotation.

BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_LAST_N="${KEEP_LAST_N:-10}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S%N)
BACKUP_NAME="vibecode_backup_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo "📦 VibeCode Backup"
echo "=================="
echo "Target: $BACKUP_PATH"
echo ""

mkdir -p "$BACKUP_DIR"

# Collect items to back up
ITEMS=()
[ -f ".env" ] && ITEMS+=(".env")
[ -d "logs" ] && ITEMS+=("logs")
[ -d "data" ] && ITEMS+=("data")
[ -f "n8n-workflow.json" ] && ITEMS+=("n8n-workflow.json")

if [ ${#ITEMS[@]} -eq 0 ]; then
    echo "⚠️  Nothing to back up."
    exit 0
fi

echo "Including: ${ITEMS[*]}"
tar czf "$BACKUP_PATH" "${ITEMS[@]}"

# Prune old backups (keep last N)
echo "🧹 Pruning backups older than last $KEEP_LAST_N..."
cd "$BACKUP_DIR"
ls -t vibecode_backup_*.tar.gz 2>/dev/null | tail -n +$((KEEP_LAST_N + 1)) | while read -r old_backup; do
    echo "   Removing $old_backup"
    rm -f "$old_backup"
done

echo ""
echo "✅ Backup complete: $BACKUP_PATH"
