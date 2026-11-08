#!/bin/bash

# Configuration
TOTAL_COMMITS=2000       # Total number of commits you want to generate
CHUNK_SIZE=500          # Number of commits to package together per push
DELAY_BETWEEN_PUSHES=15 # Time to wait (in seconds) between pushes to respect rate limits
TARGET_FILE="activity_log.txt"
BRANCH_NAME=$(git branch --show-current)

# Step 1: Ensure we are in a Git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: This directory is not a Git repository."
    exit 1
fi

# Step 2: Double check if remote origin is configured
if ! git remote | grep -q "origin"; then
    echo "❌ Error: No remote named 'origin' found. Add your GitHub repository first."
    exit 1
fi

echo "🚀 Starting localized generation of $TOTAL_COMMITS commits..."

# Step 3: Fast, local-only generation loop
for ((i=1; i<=TOTAL_COMMITS; i++))
do
    echo "Log entry: $(date) - iteration $i" >> "$TARGET_FILE"
    git add "$TARGET_FILE"
    
    # Optional: If you want to simulate backdated timeline placement, 
    # uncomment the line below and adjust the date parameter.
    # git commit --date="2026-01-01 12:00:$((i % 60))" -m "Automated build trace #$i"
    
    git commit -m "Automated build trace #$i" > /dev/null
done

echo "✅ Local generation complete. Getting ready to push safely..."

# Step 4: Safe, chunked pushing workflow
# Fetch all unpushed commits on the current branch relative to origin
COMMITS_TO_PUSH=($(git log origin/$BRANCH_NAME..$BRANCH_NAME --reverse --format="%H"))
TOTAL_UNPUSHED=${#COMMITS_TO_PUSH[@]}

if [ "$TOTAL_UNPUSHED" -eq 0 ]; then
    echo "✨ All commits are already pushed."
    exit 0
fi

echo "📦 Found $TOTAL_UNPUSHED local commits to upload. Splitting into chunks of $CHUNK_SIZE..."

current_idx=0
while [ $current_idx -lt $TOTAL_UNPUSHED ]
do
    # Calculate target index for the end of the current chunk
    target_idx=$((current_idx + CHUNK_SIZE - 1))
    
    # Cap at final index if total doesn't split evenly
    if [ $target_idx -ge $TOTAL_UNPUSHED ]; then
        target_idx=$((TOTAL_UNPUSHED - 1))
    fi
    
    # Grab the target commit hash for this chunk threshold
    target_sha=${COMMITS_TO_PUSH[$target_idx]}
    chunk_num=$(( (current_idx / CHUNK_SIZE) + 1 ))
    
    echo "📤 Pushing chunk #$chunk_num (up to commit ${target_sha:0:7})..."
    
    # Push safely up to the current chunk's specific hash
    git push origin "$target_sha:refs/heads/$BRANCH_NAME"
    
    current_idx=$((target_idx + 1))
    
    # If there are more chunks remaining, apply the rate-limit delay
    if [ $current_idx -lt $TOTAL_UNPUSHED ]; then
        echo "⏳ Sleeping for $DELAY_BETWEEN_PUSHES seconds to respect GitHub API limits..."
        sleep $DELAY_BETWEEN_PUSHES
    fi
done

echo "🎉 Success! All commits have been pushed sequentially without network failures."
