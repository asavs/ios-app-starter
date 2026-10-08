#!/usr/bin/env python3
"""Portable read-only readiness report. Account access is explicitly opt-in."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BUNDLE = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")


def finding(check, status, evidence, next_action):
    return dict(check=check, status=status, evidence=evidence, nextAction=next_action)


def configuration(path):
    records = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(records, list) or len(records) != 2:
        raise ValueError("Expected the two configuration records exported by check-configuration.py")
    if {r.get("configuration") for r in records if isinstance(r, dict)} != {"Debug", "Release"}:
        raise ValueError("Expected Debug and Release configuration records")
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("Invalid configuration record")
        if not BUNDLE.fullmatch(str(record.get("bundleIdentifier", ""))):
            raise ValueError("Invalid exported bundle identifier")
        if not re.fullmatch(r"\d+(?:\.\d+)*", str(record.get("minimumIOS", ""))):
            raise ValueError("Invalid exported deployment minimum")
    if len({r["bundleIdentifier"] for r in records}) != 1:
        raise ValueError("Debug and Release bundle identifiers differ")
    return records


class Reader:
    """Fixed GET-command interface; isolated config, no login or credential persistence."""
    def __init__(self, binary, environment, directory):
        self.binary = str(Path(binary).resolve())
        self.env = {k: v for k, v in environment.items() if not k.startswith("ASC_")}
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_TYPE", "ASC_PRIVATE_KEY", "ASC_PRIVATE_KEY_PATH", "ASC_PRIVATE_KEY_B64"):
            if name in environment:
                self.env[name] = environment[name]
        self.env.update(ASC_CONFIG_PATH=str(Path(directory) / "absent-config.json"),
                        ASC_BYPASS_KEYCHAIN="1", ASC_STRICT_AUTH="1",
                        ASC_TELEMETRY_DISABLED="1", DO_NOT_TRACK="1",
                        TMPDIR=str(Path(directory).resolve()), TMP=str(Path(directory).resolve()),
                        TEMP=str(Path(directory).resolve()))

    def read(self, command):
        # Commands are constructed only below, never from a user-supplied shell string.
        try:
            result = subprocess.run([self.binary, *command, "--paginate", "--output", "json"],
                                    env=self.env, capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return "not_verified", None
        if result.returncode:
            # asc's human errors don't reliably include HTTP status. Be conservative;
            # raw errors can contain account data or credentials and are never emitted.
            error = result.stderr.lower()
            if any(s in error for s in ("forbidden", "not authorized", "access denied")):
                return "inaccessible", None
            if any(s in error for s in ("unauthorized", "authentication credentials", "not authenticated")):
                return "authentication_failed", None
            return "not_verified", None
        try:
            data = json.loads(result.stdout)["data"]
            if not isinstance(data, list) or any(not isinstance(item, dict) for item in data):
                raise ValueError()
            return "verified", data
        except (ValueError, KeyError, TypeError):
            return "not_verified", None


def account_checks(reader, bundle):
    findings = []
    commands = [("app_record", ["apps", "list", "--bundle-id", bundle]),
                ("bundle_id", ["bundle-ids", "list", "--identifier", bundle]),
                ("distribution_certificates", ["certificates", "list", "--certificate-type", "DISTRIBUTION,IOS_DISTRIBUTION", "--fields", "certificateType,expirationDate"])]
    bundle_resource = None
    for check, command in commands:
        status, data = reader.read(command)
        if status == "verified":
            status = "present" if data else "missing"
            evidence = f"Read completed: {len(data)} accessible matching record(s)."
            if check == "bundle_id" and data:
                candidate = data[0].get("id", "")
                if isinstance(candidate, str) and re.fullmatch(r"[A-Za-z0-9-]+", candidate):
                    bundle_resource = candidate
        else:
            evidence = "Read did not establish existence; permissions, credentials, agreements, network or tool response may need review."
        findings.append(finding(check, status, evidence,
            "Review account access and existing records; plan any creation in milestone 5. Certificate presence does not prove an unexpired certificate or possession of its private key." if check == "distribution_certificates" else
            "Review the intended team, key permissions and existing records before planning account changes."))
    if bundle_resource:
        status, data = reader.read(["bundle-ids", "profiles", "list", "--id", bundle_resource])
        if status == "verified":
            status = "present" if data else "missing"
            evidence = f"Read completed: {len(data)} profile(s) linked to the app bundle ID."
        else:
            evidence = "Linked profiles could not be verified."
    else:
        status, evidence = "not_verified", "No accessible bundle ID resource was established."
    findings.append(finding("provisioning_profiles", status, evidence,
                            "Milestone 5 must check profile expiry, state, distribution type, capabilities and certificate/private-key match."))
    return findings


def diagnose(records=None, account=False, binary=None, environment=None, reader=None):
    environment = os.environ if environment is None else environment
    findings = []
    if records:
        bundle = records[0]["bundleIdentifier"]
        findings.append(finding("project_configuration", "reported",
            f"Xcode-exported Debug/Release records supplied; minimum iOS {records[0]['minimumIOS']}. This does not prove artifact freshness or minimum-OS runtime coverage.",
            "Match the artifact run and commit to the project.yml revision you intend to release."))
        findings.append(finding("bundle_identifier", "placeholder" if bundle.startswith("com.example.") else "configured",
            "Configured identifier inspected.", "Choose a unique identifier belonging to your app before signing."))
    else:
        bundle = None
        findings.append(finding("project_configuration", "not_verified", "No Xcode configuration export supplied.",
            "Run iOS CI, download ios-test-results-starter, then supply its configuration.json with --configuration."))
    kind = environment.get("ASC_KEY_TYPE", "team")
    complete = bool(environment.get("ASC_KEY_ID")) and kind in ("team", "individual") and bool(
        environment.get("ASC_PRIVATE_KEY") or environment.get("ASC_PRIVATE_KEY_B64") or environment.get("ASC_PRIVATE_KEY_PATH")) and (kind == "individual" or bool(environment.get("ASC_ISSUER_ID")))
    findings.append(finding("credentials", "configured" if complete else "not_configured",
        "Environment credential fields are complete; validity is not established." if complete else "Complete environment credentials were not supplied.",
        "Use the Apple setup guide; enter secrets securely, never into chat. Offline diagnostics do not read key files or contact Apple."))
    if account and complete and bundle and (binary or reader):
        if reader:
            findings.extend(account_checks(reader, bundle))
        else:
            with tempfile.TemporaryDirectory(prefix="apple-doctor-") as directory:
                findings.extend(account_checks(Reader(binary, environment, directory), bundle))
    else:
        findings.append(finding("account_reads", "not_verified", "Authenticated account reads were not performed.",
            "Opt in with --account --asc after supplying a configuration export and complete credentials."))
    for check, action in [("membership_and_agreements", "The Account Holder must review active membership and agreements in Apple's websites."),
                          ("signing_readiness", "Complete milestone 5: validate a signed archive with matching credentials and profiles."),
                          ("device_delivery", "Complete milestone 6: upload to TestFlight and install on the iPhone.")]:
        findings.append(finding(check, "not_verified", "This diagnostic does not establish readiness for this step.", action))
    return {"schemaVersion": 1, "generatedAt": datetime.now(timezone.utc).isoformat(), "accountRequested": account, "findings": findings}


def markdown(report):
    lines = ["# Apple setup diagnostics", "", "Read-only report; account changes and signing were not performed.", ""]
    for item in report["findings"]:
        lines.extend([f"- **{item['check']} — {item['status']}**: {item['evidence']} Next: {item['nextAction']}", ""])
    return "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--configuration", type=Path)
    parser.add_argument("--account", action="store_true")
    parser.add_argument("--asc", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path("build/apple-diagnostics"))
    args = parser.parse_args()
    try:
        report = diagnose(configuration(args.configuration) if args.configuration else None, args.account, args.asc)
        args.output_dir.mkdir(parents=True, exist_ok=True)
        (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        content = markdown(report)
        (args.output_dir / "report.md").write_text(content, encoding="utf-8")
        print(content)
    except (OSError, ValueError, TypeError, KeyError):
        parser.exit(1, "Diagnostics could not read the configuration or write the report; no raw input was logged.\n")
