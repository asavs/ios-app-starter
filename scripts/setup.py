#!/usr/bin/env python3
"""Guide and resume the Windows-first app setup without storing credentials."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STATE = ROOT / "build" / "setup-state.json"
CONSENTS = (
    "github-settings",
    "apple-read",
    "apple-provisioning",
    "apple-testflight",
    "apple-browser",
    "device-install",
)
STAGES = {
    "A": ("Repository setup", "github-settings"),
    "B": ("Credential-free Apple readiness", None),
    "C": ("Credentials into GitHub", "github-settings"),
    "D": ("Authenticated read-only diagnostics", "apple-read"),
    "E": ("Signed archive validation", "apple-provisioning"),
    "F": ("TestFlight group", "apple-testflight"),
    "G": ("TestFlight delivery", "apple-testflight"),
    "H": ("Install on the iPhone", None),
}
SCHEMA = 1


class SetupError(Exception):
    pass


def fresh_state() -> dict:
    return {"schema": SCHEMA, "consent": {}, "completed": []}


def load_state(path: Path) -> dict:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return fresh_state()
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SetupError(f"Cannot read setup state at {path}: {error}") from error
    if not isinstance(state, dict) or state.get("schema") != SCHEMA:
        raise SetupError("Setup state has an unsupported format; preserve it and use --reset only if you want to start over.")
    consent = state.get("consent")
    completed = state.get("completed")
    if (not isinstance(consent, dict) or not isinstance(completed, list)
            or any(name not in CONSENTS or type(value) is not bool for name, value in consent.items())
            or any(not isinstance(stage, str) or stage not in STAGES for stage in completed)
            or len(set(completed)) != len(completed)
            or completed != list(STAGES)[:len(completed)]):
        raise SetupError("Setup state is invalid. No setup actions were taken.")
    return state


def save_state(path: Path, state: dict) -> None:
    """Atomically store only consent decisions and completed stage names."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".setup-state-", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(state, stream, indent=2, sort_keys=True)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def next_stage(state: dict) -> str | None:
    return next((key for key in STAGES if key not in state["completed"]), None)


def show_status(state: dict, path: Path) -> None:
    current = next_stage(state)
    print(f"Setup state: {path}")
    print("Consent (stored locally; no credentials are stored):")
    for category in CONSENTS:
        value = state["consent"].get(category)
        label = "granted" if value is True else "declined" if value is False else "not answered"
        print(f"  {category}: {label}")
    print("Stages:")
    for key, (title, category) in STAGES.items():
        status = "complete" if key in state["completed"] else "next" if key == current else "pending"
        gate = f"; requires {category} consent" if category else ""
        print(f"  {key}. {title}: {status}{gate}")
    if current:
        print(f"\nNext: Stage {current} — {STAGES[current][0]}.")
        print(f"Follow docs/agent-onboarding.md#stage-{current.lower()} before recording completion.")
    else:
        print("\nAll onboarding stages are recorded complete.")


def record_consent(state: dict, category: str, granted: bool) -> None:
    state["consent"][category] = granted


def print_stage_instructions(stage: str) -> None:
    runbook = ROOT / "docs" / "agent-onboarding.md"
    try:
        lines = runbook.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise SetupError(f"Cannot read {runbook}: {error}") from error
    marker = f"### Stage {stage}:"
    start = next((index for index, line in enumerate(lines) if line.startswith(marker)), None)
    if start is None:
        raise SetupError(f"The runbook does not contain Stage {stage}.")
    end = next((index for index in range(start + 1, len(lines))
                if lines[index].startswith("### Stage ") or lines[index].startswith("## ")), len(lines))
    print("\n".join(lines[start:end]).strip())


def mark_complete(state: dict, stage: str) -> None:
    current = next_stage(state)
    if current != stage:
        raise SetupError(f"Only the next stage can be completed (next stage: {current or 'none'}).")
    _, category = STAGES[stage]
    if category and state["consent"].get(category) is not True:
        raise SetupError(f"Stage {stage} requires an explicit {category} grant. Record it with --grant {category} after the owner agrees.")
    state["completed"].append(stage)


def run_interactive(state: dict, state_path: Path) -> None:
    print("Guided setup records consent and checkpoints. Follow the runbook for each action.")
    print("It never asks for or stores passwords, Apple keys, signing passwords, or two-factor codes.\n")
    for category in CONSENTS:
        if category in state["consent"]:
            continue
        answer = input(f"Grant {category} for this repository setup? [y/N] ").strip().casefold()
        record_consent(state, category, answer in ("y", "yes"))
        save_state(state_path, state)
    while (stage := next_stage(state)) is not None:
        title, category = STAGES[stage]
        if category and state["consent"].get(category) is not True:
            print(f"Stage {stage} ({title}) is paused: {category} was not granted.")
            print("Grant it later with --grant <category>, or leave setup paused.")
            break
        print(f"\nStage {stage}: {title}")
        print_stage_instructions(stage)
        answer = input("Have you completed this stage and its checks? [y/N] ").strip().casefold()
        if answer not in ("y", "yes"):
            print("Paused. Your completed stages and consent choices are saved.")
            break
        mark_complete(state, stage)
        save_state(state_path, state)
    show_status(state, state_path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE,
                        help="local checkpoint file (default: build/setup-state.json)")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--status", action="store_true", help="show saved consent and stage progress")
    actions.add_argument("--grant", choices=CONSENTS, help="record an owner's explicit consent grant")
    actions.add_argument("--decline", choices=CONSENTS, help="record that consent was declined")
    actions.add_argument("--complete", choices=tuple(STAGES), metavar="STAGE",
                         help="record the current stage complete after its runbook checks pass")
    actions.add_argument("--reset", action="store_true", help="delete the checkpoint and start over")
    args = parser.parse_args(argv)
    try:
        path = args.state.expanduser().resolve()
        if args.reset:
            path.unlink(missing_ok=True)
            print(f"Removed setup checkpoint: {path}")
            return 0
        state = load_state(path)
        if args.grant:
            record_consent(state, args.grant, True)
            save_state(path, state)
            print(f"Recorded {args.grant} consent. No account action was taken.")
        elif args.decline:
            record_consent(state, args.decline, False)
            save_state(path, state)
            print(f"Recorded declined {args.decline} consent. No account action was taken.")
        elif args.complete:
            mark_complete(state, args.complete)
            save_state(path, state)
            print(f"Recorded Stage {args.complete} complete.")
        elif args.status:
            pass
        else:
            run_interactive(state, path)
        if args.status or args.grant or args.decline or args.complete:
            show_status(state, path)
    except (SetupError, OSError, EOFError) as error:
        print(f"Setup paused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
