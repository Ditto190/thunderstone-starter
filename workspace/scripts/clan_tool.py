#!/usr/bin/env python3
"""
clan_tool.py — Personal DX & Clan Diagnostics Tool for Thunderstone
===================================================================
A lightweight, zero-dependency personal CLI built for fast developer feedback loops.
Works identically on Windows (via `py`) and Linux VM (via `python3`).

Usage:
    py workspace/scripts/clan_tool.py doctor
    py workspace/scripts/clan_tool.py status
    py workspace/scripts/clan_tool.py verify <handoff_id>
    py workspace/scripts/clan_tool.py check <handoff_id>
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
WORKSPACE_DIR = REPO_ROOT / "workspace"
BRIEFS_DIR = WORKSPACE_DIR / "briefs"
HANDOFFS_DIR = WORKSPACE_DIR / "handoffs"


def cmd_doctor():
    """Run comprehensive environment & DX doctor checks."""
    print("=" * 60)
    print(" Thunderstone Clan Doctor — Environment Diagnostics")
    print("=" * 60)

    # 1. Node.js Check
    node_bin = shutil.which("node")
    if node_bin:
        try:
            ver = subprocess.check_output([node_bin, "--version"], text=True).strip()
            print(f"[OK]   Node.js: {ver} ({node_bin})")
        except Exception:
            print("[WARN] Node.js is installed but failed version check.")
    else:
        print("[FAIL] Node.js is NOT found on PATH.")

    # 2. Python Check
    py_ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    if sys.version_info >= (3, 10):
        print(f"[OK]   Python: {py_ver}")
    else:
        print(f"[WARN] Python version {py_ver} is older than recommended (3.10+).")

    # 3. AG2 / AutoGen Check
    try:
        import autogen
        print(f"[OK]   AG2 (AutoGen): v{getattr(autogen, '__version__', 'unknown')}")
    except ImportError:
        print("[WARN] AG2 / AutoGen not found. (Run `pip install ag2` or use mock mode)")

    # 4. Git Check
    git_bin = shutil.which("git")
    if git_bin:
        try:
            branch = subprocess.check_output([git_bin, "branch", "--show-current"], text=True, stderr=subprocess.DEVNULL).strip()
            print(f"[OK]   Git: on branch '{branch or 'detached'}'")
        except Exception:
            print("[OK]   Git: installed")
    else:
        print("[WARN] Git not found on PATH.")

    # 5. Google Cloud SDK & ADC
    gcloud_bin = shutil.which("gcloud")
    if gcloud_bin:
        print(f"[OK]   Google Cloud SDK: available")
    else:
        print("[WARN] gcloud CLI not found on PATH.")

    # 6. DAK Configuration Check
    dak_cfg_path = Path.home() / ".gemini" / "config" / "plugins" / "data-agent-kit-plugin"
    if dak_cfg_path.exists():
        print("[OK]   Google Cloud Data Agent Kit: plugin folder present")
    else:
        print("[INFO] Data Agent Kit plugin directory not found locally.")

    # 7. Workspace Folders
    print(f"[OK]   Workspace Briefs: {'Found' if BRIEFS_DIR.exists() else 'Missing'}")
    print(f"[OK]   Workspace Handoffs: {'Found' if HANDOFFS_DIR.exists() else 'Missing'}")
    print("=" * 60)
    print("Diagnostics complete.")


def cmd_status():
    """Report recent briefs and handoffs."""
    print("=" * 60)
    print(" Thunderstone Clan Status")
    print("=" * 60)

    print("\nRecent Briefs:")
    if BRIEFS_DIR.exists():
        briefs = list(BRIEFS_DIR.glob("*.md"))
        if briefs:
            for b in sorted(briefs, key=lambda x: x.stat().st_mtime, reverse=True)[:5]:
                mtime = time.strftime("%Y-%m-%d %H:%M", time.localtime(b.stat().st_mtime))
                print(f"  - {b.name:<30} ({mtime})")
        else:
            print("  (No briefs found)")
    else:
        print("  (Briefs directory does not exist)")

    print("\nRecent Handoffs:")
    if HANDOFFS_DIR.exists():
        handoffs = [d for d in HANDOFFS_DIR.iterdir() if d.is_dir()]
        if handoffs:
            for h in sorted(handoffs, key=lambda x: x.stat().st_mtime, reverse=True)[:5]:
                receipts = list(h.glob("receipt-*.json"))
                roles = []
                for r in receipts:
                    try:
                        with open(r, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            roles.append(f"{data.get('role')}:{data.get('status')}")
                    except Exception:
                        pass
                roles_str = " -> ".join(roles) if roles else "empty"
                print(f"  - {h.name:<25} [{roles_str}]")
        else:
            print("  (No handoffs recorded)")
    else:
        print("  (Handoffs directory does not exist)")
    print("=" * 60)


def cmd_verify(handoff_id: str):
    """Verify receipt chain and invariants for a handoff."""
    target_dir = HANDOFFS_DIR / handoff_id
    if not target_dir.exists():
        print(f"[ERROR] Handoff directory not found: {handoff_id}")
        sys.exit(1)

    receipts = []
    for r in target_dir.glob("receipt-*.json"):
        try:
            with open(r, "r", encoding="utf-8") as f:
                receipts.append(json.load(f))
        except Exception as e:
            print(f"[WARN] Failed to parse {r.name}: {e}")

    if not receipts:
        print(f"[ERROR] No valid receipts found for {handoff_id}")
        sys.exit(1)

    receipts.sort(key=lambda x: x.get("created_at_ms", 0))

    print("=" * 60)
    print(f" Handoff Receipt Chain: {handoff_id}")
    print("=" * 60)
    for r in receipts:
        role = r.get("role", "unknown")
        status = r.get("status", "unknown")
        rid = r.get("receipt_id", "unknown")
        val = r.get("validation", {})
        passed = val.get("passed") if isinstance(val, dict) else val
        print(f"  Receipt ID: {rid}")
        print(f"    Role:       {role}")
        print(f"    Status:     {status}")
        print(f"    Validation: passed={passed}")
        print()
    print("=" * 60)


def cmd_check(handoff_id: str):
    """Check promotion decision."""
    target_dir = HANDOFFS_DIR / handoff_id
    if not target_dir.exists():
        print(f"promotion_blocked missing_handoff_dir")
        sys.exit(1)

    verifier_receipts = []
    for r in target_dir.glob("receipt-*.json"):
        try:
            with open(r, "r", encoding="utf-8") as f:
                d = json.load(f)
                if d.get("role") == "verifier":
                    verifier_receipts.append(d)
        except Exception:
            pass

    if not verifier_receipts:
        print("promotion_blocked no_verifier_receipt")
        sys.exit(1)

    verifier_receipts.sort(key=lambda x: x.get("created_at_ms", 0))
    latest = verifier_receipts[-1]
    status = latest.get("status")
    val = latest.get("validation", {})
    passed = val.get("passed") if isinstance(val, dict) else False

    if status == "accepted" and passed is True:
        print("promotion_allowed")
        sys.exit(0)
    else:
        print(f"promotion_blocked status={status} validation_passed={passed}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Thunderstone Clan Personal DX CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("doctor", help="Check local environment diagnostics")
    subparsers.add_parser("status", help="Show recent briefs and handoff chains")

    p_verify = subparsers.add_parser("verify", help="Inspect receipt chain for a handoff")
    p_verify.add_argument("handoff_id", type=str)

    p_check = subparsers.add_parser("check", help="Check if handoff passes promotion gate")
    p_check.add_argument("handoff_id", type=str)

    args = parser.parse_args()

    if args.command == "doctor":
        cmd_doctor()
    elif args.command == "status":
        cmd_status()
    elif args.command == "verify":
        cmd_verify(args.handoff_id)
    elif args.command == "check":
        cmd_check(args.handoff_id)


if __name__ == "__main__":
    main()
