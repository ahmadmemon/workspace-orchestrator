#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

failed=0

check_absent() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -n --hidden --glob '!.git/**' --glob '!.build/**' --glob '!dist/**' "$pattern" "$@"; then
    echo "security audit failed: $label"
    failed=1
  fi
}

check_absent "shell-wrapper execution" '(Process|executable|executableURL).*((/bin/(sh|bash|zsh))([^A-Za-z0-9_]|$)|(sh|bash|zsh) -c)' App Packages
check_absent "privileged or script-wrapper execution" '(Process|executable|executableURL).*(/usr/bin/(sudo|osascript|env))' App Packages
check_absent "TLS validation bypass" '(allowsAnyHTTPSCertificate|serverTrust.*useCredential|kCFStreamSSLAllowsAnyRoot|NSAllowsArbitraryLoads)' App Packages
check_absent "embedded private key" 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' .
check_absent "hard-coded GitHub token" 'gh[opsu]_[A-Za-z0-9]{20,}' .
check_absent "hard-coded OpenAI key" 'sk-[A-Za-z0-9_-]{20,}' .

if [[ "$failed" -ne 0 ]]; then exit 1; fi

required_docs=(
  README.md docs/ARCHITECTURE.md docs/PRODUCT_SPEC.md docs/SECURITY_MODEL.md
  docs/USER_GUIDE.md docs/QUICK_START.md docs/SCENE_BUILDER.md docs/INTEGRATIONS.md
  docs/PERMISSIONS.md docs/PRIVACY.md docs/THREAT_MODEL.md docs/TROUBLESHOOTING.md
  docs/IMPORT_EXPORT.md docs/RELEASE.md docs/SMOKE_TEST.md docs/DESIGN_SYSTEM.md
  docs/V1_SCOPE.md docs/V1_EXECUTION_PLAN.md
)
for document in "${required_docs[@]}"; do
  if [[ ! -s "$document" ]]; then echo "documentation audit failed: missing $document"; failed=1; fi
done

if [[ "$failed" -ne 0 ]]; then exit 1; fi
echo "Security and documentation audit passed."
