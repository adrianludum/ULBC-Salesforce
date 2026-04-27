#!/usr/bin/env python3
"""
Merge partner contacts into shared NPSP Household Accounts.

For each partner pair, moves the second contact into the first contact's
household. NPSP automatically updates rollups and member counts.

Usage:
    python data/merge_households.py --dry-run   # Preview changes
    python data/merge_households.py             # Execute merge
"""

import argparse
import json
import subprocess
import sys


def sf_query(query: str) -> list:
    result = subprocess.run(
        ["sf", "data", "query", "--query", query,
         "--target-org", "ulbc", "--result-format", "json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    return data.get("result", {}).get("records", [])


def sf_update(sobject: str, record_id: str, fields: dict) -> bool:
    values = " ".join(f"{k}={v}" for k, v in fields.items())
    result = subprocess.run(
        ["sf", "data", "update", "record",
         "--sobject", sobject,
         "--record-id", record_id,
         "--values", values,
         "--target-org", "ulbc"],
        capture_output=True, text=True
    )
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description="Merge partner households")
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    args = parser.parse_args()

    print("Querying partner relationships...")
    records = sf_query(
        "SELECT npe4__Contact__c, npe4__Contact__r.Name, "
        "npe4__Contact__r.AccountId, npe4__Contact__r.Account.Name, "
        "npe4__RelatedContact__c, npe4__RelatedContact__r.Name, "
        "npe4__RelatedContact__r.AccountId, npe4__RelatedContact__r.Account.Name "
        "FROM npe4__Relationship__c "
        "WHERE npe4__Type__c = 'Partner' AND npe4__Status__c = 'Current'"
    )

    # De-duplicate: each pair appears as A→B and B→A
    seen = set()
    pairs = []
    for r in records:
        c1 = r["npe4__Contact__c"]
        c2 = r["npe4__RelatedContact__c"]
        pair = tuple(sorted([c1, c2]))
        if pair in seen:
            continue
        seen.add(pair)

        a1 = r["npe4__Contact__r"]["AccountId"]
        a2 = r["npe4__RelatedContact__r"]["AccountId"]

        if a1 == a2:
            print(f"  SKIP (already same household): "
                  f"{r['npe4__Contact__r']['Name']} & "
                  f"{r['npe4__RelatedContact__r']['Name']}")
            continue

        pairs.append({
            "keep_contact": r["npe4__Contact__r"]["Name"],
            "keep_account": a1,
            "keep_household": r["npe4__Contact__r"]["Account"]["Name"],
            "move_contact": r["npe4__RelatedContact__r"]["Name"],
            "move_contact_id": c2,
            "move_account": a2,
            "move_household": r["npe4__RelatedContact__r"]["Account"]["Name"],
        })

    if not pairs:
        print("No households to merge.")
        return

    print(f"\n{'DRY RUN - ' if args.dry_run else ''}Merging {len(pairs)} household pairs:\n")
    print(f"  {'Partner 1':<30s} {'Partner 2':<30s} {'Into Household'}")
    print(f"  {'-'*30} {'-'*30} {'-'*30}")

    success = 0
    failed = 0
    empty_accounts = []

    for p in pairs:
        print(f"  {p['keep_contact']:<30s} {p['move_contact']:<30s} → {p['keep_household']}")

        if args.dry_run:
            continue

        # Move the second contact into the first contact's household
        ok = sf_update("Contact", p["move_contact_id"],
                       {"AccountId": p["keep_account"]})
        if ok:
            success += 1
            empty_accounts.append(p["move_account"])
            print(f"    ✓ Moved {p['move_contact']} into {p['keep_household']}")
        else:
            failed += 1
            print(f"    ✗ FAILED to move {p['move_contact']}")

    if args.dry_run:
        print(f"\nDry run complete. {len(pairs)} pairs would be merged.")
        print("Run without --dry-run to execute.")
    else:
        print(f"\nDone: {success} merged, {failed} failed")
        if empty_accounts:
            print(f"\n{len(empty_accounts)} empty household accounts can be cleaned up.")
            print("NPSP should auto-delete empty households, or you can delete manually.")


if __name__ == "__main__":
    main()
