#!/usr/bin/env bash
# ============================================================
# Phase 2C Deploy Script — ULBC Trust Salesforce
# ============================================================
# Two-step deploy: objects/fields first, permission set second.
# Salesforce requires the objects to exist before a permission
# set that references them can be deployed.
# ============================================================

set -e
ORG_ALIAS="ulbc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo "ULBC Phase 2C — Pre-deploy checks"
echo "============================================================"
echo "→ Checking org connection..."
sf org display --target-org "$ORG_ALIAS" --json | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('  Org: ' + d['result']['instanceUrl'])"

echo ""
echo "============================================================"
echo "Step 1 — Deploy objects, fields, and test class"
echo "============================================================"
sf project deploy start \
  --manifest "$SCRIPT_DIR/manifest/package.xml.phase2c-step1" \
  --target-org "$ORG_ALIAS" \
  --wait 10

echo ""
echo "============================================================"
echo "Step 2 — Deploy updated permission set"
echo "(Objects now exist in org — permission set references will resolve)"
echo "============================================================"
sf project deploy start \
  --manifest "$SCRIPT_DIR/manifest/package.xml.phase2c-step2" \
  --target-org "$ORG_ALIAS" \
  --wait 10

echo ""
echo "============================================================"
echo "Step 3 — Run Phase 2C tests (expect 8 passing)"
echo "============================================================"
sf apex run test \
  --class-names ULBC_Phase2C_DataModel_Test \
  --target-org "$ORG_ALIAS" \
  --result-format human \
  --wait 5

echo ""
echo "============================================================"
echo "Step 4 — Full test suite (expect 71 passing)"
echo "============================================================"
sf apex run test \
  --class-names ULBC_ContactDataModel_Test,ULBC_GoneAwayTrigger_Test,ULBC_DonorTierEngine_Test,ULBC_Phase2C_DataModel_Test \
  --target-org "$ORG_ALIAS" \
  --result-format human \
  --wait 10

echo ""
echo "============================================================"
echo "✅  Phase 2C deploy complete."
echo ""
echo "Next steps:"
echo "  1. Verify noreply@ulbctrust.org in Setup → Org-Wide Email Addresses"
echo "  2. Build the Upgrade Prospect Record-Triggered Flow"
echo "  3. Add Gift Aid section to Contact page layout"
echo "  4. Add Phase 2C fields to Opportunity page layout"
echo "  5. Add Subscriptions + Tyrian Memberships related lists to Contact layout"
echo "============================================================"
