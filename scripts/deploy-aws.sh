
#!/usr/bin/env bash
set -Eeuo pipefail

# AWS EC2 deployment with automatic rollback.
# Run as root through AWS Systems Manager.

IMAGE_URI="${1:?ERROR: Docker image URI required}"
LIVE="devops-cicd-aws"
BACKUP="devops-cicd-aws-previous-$(date +%Y%m%d%H%M%S)-$$"
URL="http://127.0.0.1:80"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Deployment must run as root."
    exit 1
fi

old_stopped=0
old_renamed=0

health_check() {
    local status

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        status=$(curl -sS --max-time 5 -o /dev/null \
            -w '%{http_code}' "$URL") || status="000"

        if [ "$status" = "200" ]; then
            return 0
        fi

        echo "Health check attempt $attempt: HTTP $status"
        sleep 2
    done

    return 1
}

rollback() {
    echo "WARNING: Deployment failed. Attempting rollback."

    if [ "$old_renamed" -eq 1 ]; then
        # Remove any failed replacement container.
        if docker container inspect "$LIVE" >/dev/null 2>&1; then
            echo "Removing failed deployment..."
            docker rm -f "$LIVE" || return 1
        fi

        echo "Restoring previous container..."
        docker rename "$BACKUP" "$LIVE" || return 1
        docker start "$LIVE" || return 1

    elif [ "$old_stopped" -eq 1 ]; then
        echo "Restarting original container..."
        docker start "$LIVE" || return 1

    else
        echo "Previous deployment was not modified."
        return 0
    fi

    echo "Verifying restored website..."

    if health_check; then
        echo "SUCCESS: Previous AWS deployment restored."
        return 0
    fi

    echo "CRITICAL: Rollback health check failed."
    return 1
}

on_error() {
    local original_status=$?
    trap - ERR INT TERM

    echo "ERROR: Deployment interrupted or failed."

    if ! rollback; then
        echo "CRITICAL: Automatic recovery failed."
        echo "Manual intervention may be required."
    fi

    if [ "$original_status" -eq 0 ]; then
        original_status=1
    fi

    exit "$original_status"
}

trap on_error ERR
trap 'exit 1' INT TERM

echo "Checking current AWS container..."
docker container inspect "$LIVE" >/dev/null

echo "Checking current website health..."
if ! health_check; then
    echo "ERROR: Existing website is not healthy."
    echo "Deployment cancelled without changing containers."
    exit 1
fi

echo "Authenticating Docker with Amazon ECR..."
REGISTRY="${IMAGE_URI%%/*}"

aws ecr get-login-password --region ap-south-1 |
    docker login --username AWS --password-stdin "$REGISTRY"

echo "Pulling new Docker image..."
docker pull "$IMAGE_URI"

echo "Stopping previous AWS deployment..."
old_stopped=1
docker stop "$LIVE"

echo "Preserving previous container..."
docker rename "$LIVE" "$BACKUP"
old_renamed=1

echo "Starting new AWS deployment..."
docker run -d \
    --name "$LIVE" \
    -p 80:80 \
    --restart unless-stopped \
    "$IMAGE_URI"

echo "Checking new website health..."
if ! health_check; then
    echo "ERROR: New deployment failed HTTP health check."
    false
fi

trap - ERR INT TERM

echo "SUCCESS: New AWS deployment is healthy."
echo "Running container: $LIVE"
echo "Backup container: $BACKUP"
