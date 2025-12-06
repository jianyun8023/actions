#!/bin/sh
set -e

# Ensure the working directory is correct
cd /app

# Replace NEXT_PUBLIC_ env variable placeholders with real values
printenv | grep NEXT_PUBLIC_ | while read -r line ; do
  key=$(echo $line | cut -d "=" -f1)
  value=$(echo $line | cut -d "=" -f2)

  find .next/ -type f -exec sed -i "s|$key|$value|g" {} \;
done
echo "Done replacing NEXT_PUBLIC_ env variables with real values"

# Set INTERNAL_API_URL for Next.js server-side API proxy
# This is used by next.config.mjs rewrites() function
if [ -n "$INTERNAL_API_URL" ]; then
  export INTERNAL_API_URL="$INTERNAL_API_URL"
  echo "INTERNAL_API_URL set to: $INTERNAL_API_URL"
elif [ -n "$NEXT_PUBLIC_API_URL" ]; then
  # Fallback: use NEXT_PUBLIC_API_URL if INTERNAL_API_URL not set
  export INTERNAL_API_URL="$NEXT_PUBLIC_API_URL"
  echo "INTERNAL_API_URL not set, using NEXT_PUBLIC_API_URL: $NEXT_PUBLIC_API_URL"
else
  # Default to internal Docker network address
  export INTERNAL_API_URL="http://openmemory-api:8765"
  echo "Using default INTERNAL_API_URL: $INTERNAL_API_URL"
fi

# Execute the container's main process (CMD in Dockerfile)
exec "$@"