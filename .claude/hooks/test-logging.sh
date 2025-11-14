#!/bin/bash

# Test script for prompt logging system

echo "Testing Prompt Logging System"
echo "=============================="
echo ""

# Change to hooks directory
cd "$(dirname "$0")"

# Test 1: Test skill-injector (should create activation cache)
echo "Test 1: Skill Injector"
echo '{"prompt":"create a new repository for user profiles","session_id":"test-session-123"}' | npx tsx skill-injector.ts > /dev/null 2>&1
if [ -f "../cache/last-skill-activation.json" ]; then
  echo "✓ Skill activation cache created"
  cat ../cache/last-skill-activation.json
else
  echo "✗ Skill activation cache NOT created"
fi
echo ""

# Test 2: Test prompt-logger (should create log entry)
echo "Test 2: Prompt Logger"
echo '{"prompt":"help me persist user data to the database","session_id":"test-session-123"}' | npx tsx prompt-logger.ts
LOG_FILE="../cache/prompt-logs/$(date +%Y-%m-%d).jsonl"
if [ -f "$LOG_FILE" ]; then
  echo "✓ Prompt log created: $LOG_FILE"
  echo "Latest entry:"
  tail -n 1 "$LOG_FILE" | python -m json.tool
else
  echo "✗ Prompt log NOT created"
fi
echo ""

# Test 3: Test file-operation-logger (should log file operation)
echo "Test 3: File Operation Logger"
echo '{"tool_name":"Edit","tool_input":{"file_path":"lib/test.dart"},"session_id":"test-session-123"}' | npx tsx file-operation-logger.ts
if [ -f "$LOG_FILE" ]; then
  echo "✓ File operation logged"
  echo "Latest entry:"
  tail -n 1 "$LOG_FILE" | python -m json.tool
else
  echo "✗ File operation NOT logged"
fi
echo ""

echo "=============================="
echo "Test complete!"
echo ""
echo "Log file location: $LOG_FILE"
echo "To view all logs: cat $LOG_FILE | python -m json.tool"
