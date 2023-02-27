#!/usr/bin/env sh

echo "feat: LOT-124 wanted"  | npx commitlint &&
echo "feat(service): LOT-124 wanted"  | npx commitlint &&
echo "feat: LOT-124 wanted self-service"  | npx commitlint &&
echo "feat: LOT-124 wAnted"  | npx commitlint &&
echo "feat: LOT-124 wanted multiple word"  | npx commitlint &&
echo "fix: LOT-124 wanted"  | npx commitlint &&
echo "fix(service): LOT-124 wanted"  | npx commitlint &&
echo "fix: LOT-124 wanted self-service"  | npx commitlint &&
echo "fix: LOT-124 wAnted"  | npx commitlint &&
echo "fix: LOT-124 wanted multiple word"  | npx commitlint &&
echo "feat: subject with jira at the end #LTT-1234"  | npx commitlint &&
echo "fix: subject with jira at the end #LTT-1234"  | npx commitlint &&
echo "chore: LOT-124 wanted"  | npx commitlint &&
echo "chore: wanted also"  | npx commitlint &&
echo "chore(node): wanted also"  | npx commitlint &&
echo "chore: wanted Also"  | npx commitlint &&
echo "build: LOT-124 wanted"  | npx commitlint &&
echo "build: wanted also"  | npx commitlint &&
echo "build: wanted Also"  | npx commitlint &&
echo "ci: LOT-124 wanted"  | npx commitlint &&
echo "ci: wanted also"  | npx commitlint &&
echo "ci: wanted Also"  | npx commitlint &&
echo "test: LOT-124 wanted"  | npx commitlint &&
echo "test: wanted also self"  | npx commitlint &&
echo "test: wanted also self-service"  | npx commitlint &&
echo "test: wanted Also"  | npx commitlint &&
echo "refactor: LOT-124 wanted"  | npx commitlint &&
echo "refactor: wanted also"  | npx commitlint &&
echo "refactor: wanted also self-service"  | npx commitlint &&
echo "refactor: wanted Also"  | npx commitlint &&
echo "docs: LOT-124 wanted"  | npx commitlint &&
echo "docs: wanted also"  | npx commitlint &&
echo "docs: wanted Also"  | npx commitlint &&
echo "revert: LOT-124 wanted"  | npx commitlint &&
echo "revert: wanted also"  | npx commitlint &&
echo "revert: wanted Also"  | npx commitlint &&
echo "💫 wanted Also"  | npx commitlint &&
echo "🐛 LTT-1234 wanted Also"  | npx commitlint &&
echo "🐛 wanted Also #LTT-1234"  | npx commitlint &&
echo "🚑️ LTT-1234 wanted Also"  | npx commitlint &&
echo "✨ LTT-1234 wanted Also"  | npx commitlint &&
echo "💄 LTT-1234 wanted Also"  | npx commitlint &&
echo "🔒️ LTT-1234 wanted Also"  | npx commitlint &&
echo "👽️ LTT-1234 wanted Also"  | npx commitlint &&
echo "💥 LTT-1234 wanted Also"  | npx commitlint &&
echo "🍱 LTT-1234 wanted Also"  | npx commitlint &&
echo "♿️ LTT-1234 wanted Also"  | npx commitlint &&
echo "🚸 LTT-1234 wanted Also"  | npx commitlint &&
echo "🚩 LTT-1234 wanted Also"  | npx commitlint &&
echo "🩹 LTT-1234 wanted Also"  | npx commitlint &&
echo "\n Passing test PASSED" || exit 1


echo "chore: Unwanted"  | npx commitlint ||
echo "feat(commitlint): LTT-4062 No uppercase as first char" | npx commitlint ||
echo "feat: LOT-124 Unwanted"  | npx commitlint ||
echo "fix: LOT-124 Unwanted"  | npx commitlint ||
echo "fix: LOT-124"  | npx commitlint ||
echo "feat: LOT-124"  | npx commitlint ||
echo "feat: subject with no jira at the end"  | npx commitlint ||
echo "fix: subject with no jira at the end"  | npx commitlint ||
echo "feat: subject with no jira at the end #LTT1234"  | npx commitlint ||
echo "fix: subject with no jira at the end #LTT1234"  | npx commitlint ||
echo "feat: subject with no jira at the end #LTT-"  | npx commitlint ||
echo "fix: subject with no jira at the end #LTT-"  | npx commitlint ||
echo "feat: subject with no jira at the end #-1234"  | npx commitlint ||
echo "fix: subject with no jira at the end #-1234"  | npx commitlint ||
echo "🐛 unwanted Also"  | npx commitlint ||
echo "🚑️ unwanted Also"  | npx commitlint ||
echo "✨ unwanted Also"  | npx commitlint ||
echo "💄 unwanted Also"  | npx commitlint ||
echo "🔒️ unwanted Also"  | npx commitlint ||
echo "👽️ unwanted Also"  | npx commitlint ||
echo "💥 unwanted Also"  | npx commitlint ||
echo "🍱 unwanted Also"  | npx commitlint ||
echo "♿️ unwanted Also"  | npx commitlint ||
echo "🚸 unwanted Also"  | npx commitlint ||
echo "🚩 unwanted Also"  | npx commitlint ||
echo "🩹 unwanted Also"  | npx commitlint || echo "\n Non-passing test PASSED"

exit $?
