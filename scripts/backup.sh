#!/bin/bash
set -e

BACKUP_DIR="/opt/backups"
BACKUP_KEY="/home/devops/.ssh/backup_key"

# Move the backup key from tmp to the right place
mv /tmp/backup_key "$BACKUP_KEY"
chown devops:devops "$BACKUP_KEY"
chmod 600 "$BACKUP_KEY"

# Create backup directory
mkdir -p "$BACKUP_DIR"
chown devops:devops "$BACKUP_DIR"

# Write the backup script
cat > /opt/backup.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/opt/backups"
BACKUP_KEY="/home/devops/.ssh/backup_key"
TIMESTAMP=$(date +%Y-%m-%d)

SERVERS=(
    "loadbalancer"
    "webserver01"
    "webserver02"
    "appserver"
)

for SERVER in "${SERVERS[@]}"; do
    DEST="$BACKUP_DIR/$TIMESTAMP/$SERVER"
    mkdir -p "$DEST"

    # Backup /etc
    rsync -az --delete \
        -e "ssh -i $BACKUP_KEY -o StrictHostKeyChecking=no" \
        --rsync-path="sudo rsync" \
        devops@$SERVER:/etc/ \
        "$DEST/etc/"

    # Backup /home/devops
    rsync -az --delete \
        -e "ssh -i $BACKUP_KEY -o StrictHostKeyChecking=no" \
        --rsync-path="sudo rsync" \
        devops@$SERVER:/home/devops/ \
        "$DEST/home/"

    echo "Backed up $SERVER to $DEST"
done

echo "Backup completed: $TIMESTAMP"
EOF

chmod +x /opt/backup.sh
chown devops:devops /opt/backup.sh

# Write the restore script
cat > /opt/restore.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/opt/backups"
BACKUP_KEY="/home/devops/.ssh/backup_key"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./restore.sh <date> <server-ip>"
    echo "Example: ./restore.sh 2026-01-01 appserver"
    exit 1
fi

DATE=$1
SERVER=$2
SOURCE="$BACKUP_DIR/$DATE/$SERVER"

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: No backup found for $SERVER on $DATE"
    exit 1
fi

echo "Restoring $SERVER from $DATE..."

# Restore /etc
rsync -az \
    -e "ssh -i $BACKUP_KEY -o StrictHostKeyChecking=no" \
    --rsync-path="sudo rsync" \
    "$SOURCE/etc/" \
    devops@$SERVER:/etc/

# Restore /home/devops
rsync -az \
    -e "ssh -i $BACKUP_KEY -o StrictHostKeyChecking=no" \
    --rsync-path="sudo rsync" \
    "$SOURCE/home/" \
    devops@$SERVER:/home/devops/

echo "Restore completed for $SERVER from $DATE"
EOF

chmod +x /opt/restore.sh
chown devops:devops /opt/restore.sh

# Schedule weekly backup via cron
CRON_JOB="0 2 * * 0 /opt/backup.sh >> /var/log/backup.log 2>&1"
echo "$CRON_JOB" | sudo -u devops crontab -

echo "Backup system configured successfully"