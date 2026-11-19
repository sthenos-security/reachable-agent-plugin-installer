# Copyright © 2026 Sthenos Security. All rights reserved.
"""The uninstall steps that need no REACHABLE runtime (design "Two Uninstalls" U3, U9).

ONE implementation of each of these steps, used two ways:

- `reach_agent.full_uninstall` calls them for `reachctl vibe uninstall --full`
  (the runtime path), passing the runtime's own lock and atomic-write helpers.
- The plugin package ships this file as `scripts/uninstall_core.py`, next to
  `scripts/uninstall-layout.json`, which `full_uninstall.uninstall_layout()`
  generates from the same tables the runtime uses (`reach_agent.host_table`,
  `fast_path.install`, `reachable.core.settings`). The packaged `uninstall.sh`
  runs this file with `python3 -I` when the runtime is missing or broken, so a
  half-installed machine can still be cleaned (U9).

Standard library only, no `reach_agent` or `reachable` import (a machine with
no runtime has neither), and Python 3.9 syntax (macOS's own python3). What is
ours is decided by evidence, never by name: a marker file in a package
directory, `_reach_gate1_managed` on a hook entry, our managed-block markers,
our plugin ids in the host's own listing. Every step raises
`FullUninstallError` naming what is left. Every step takes `act`: with
`act=False` it changes nothing and returns what it WOULD remove.
"""

from __future__ import annotations

import argparse
import contextlib
import enum
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Callable, ContextManager, Dict, Iterator, List, Optional, Tuple

#: Files only a REACHABLE package or overlay directory carries.
#: `reachable-plugin.json`: package metadata `install-plugin.sh` requires.
#: `.reachable-plugin-installer.json`: marker the plugin installer writes.
#: `.gate1-overlay-files`: Gate 1 overlay record (`fast_path/install.py`).
PACKAGE_MARKERS: Tuple[str, ...] = (
    "reachable-plugin.json",
    ".reachable-plugin-installer.json",
    ".gate1-overlay-files",
)
#: The key Gate 1 puts on every hook entry it writes into a user's hook file.
GATE1_MANAGED_KEY = "_reach_gate1_managed"
#: Claude Code plugin ids REACHABLE publishes (catalog and local build).
CLAUDE_PLUGIN_IDS = frozenset({"reachable@sthenos-security", "reachable@reachable-local"})
#: What reach-dist `install.sh` `configure_shell_path` appends to a shell
#: startup file: a blank line, this marker, this PATH line.
INSTALLER_PATH_MARKER = "# Added by REACHABLE installer"
INSTALLER_PATH_LINE = 'export PATH="$HOME/.reachable/venv/bin:$PATH"'
#: Every file `_shell_rc_path` in install.sh may pick.
SHELL_STARTUP_FILES: Tuple[str, ...] = (".zshrc", ".bashrc", ".bash_profile", ".profile")

#: `edit_json(path, change)`: read-change-write a user's JSON file under its
#: lock, keeping the file's mode.
EditJson = Callable[[Path, Callable[[Any], Any]], None]
#: `lock(path)`: hold the file's lock while it is read and rewritten.
Lock = Callable[[Path], ContextManager[None]]
#: `write_bytes(path, data)`: replace a user's file atomically, keeping its mode.
WriteBytes = Callable[[Path, bytes], None]
Step = Callable[[bool], List[str]]


class FullUninstallError(RuntimeError):
    """A U3 step could not complete. The message names the step and what is left."""

    def __init__(self, step: str, detail: str) -> None:
        super().__init__(f"{step}: {detail}")
        self.step = step


class ManagedBlockConflict(ValueError):
    """Our managed block cannot be removed safely; the reason names `managed_block_conflict`."""


def is_reachable_package_dir(path: Path) -> bool:
    return path.is_dir() and any((path / marker).is_file() for marker in PACKAGE_MARKERS)


def run_host_cli(step: str, argv: List[str], *, timeout: float, cwd: Optional[Path] = None) -> str:
    result = subprocess.run(argv, capture_output=True, text=True, cwd=cwd, timeout=timeout)
    if result.returncode != 0:
        raise FullUninstallError(
            step,
            f"`{' '.join(argv)}` exited {result.returncode}: {(result.stderr or result.stdout).strip()}",
        )
    return result.stdout


# ------------------------------------------------------------ U3.3 host plugins


def claude_cli(home: Path) -> Optional[str]:
    """The `claude` CLI, or None when there is no marked Claude plugin evidence.

    A partial install may have a marketplace checkout but no installed-plugins
    registry. That checkout still needs the host CLI to unregister it.
    """
    registry = home / ".claude" / "plugins" / "installed_plugins.json"
    marketplaces = home / ".claude" / "plugins" / "marketplaces"
    marked_marketplace = False
    if marketplaces.is_dir():
        for marketplace in marketplaces.iterdir():
            plugins = marketplace / "plugins"
            if not plugins.is_dir():
                continue
            if any(holds_only_our_packages(child) for child in plugins.iterdir() if child.is_dir()):
                marked_marketplace = True
                break
    marked_registry = False
    if registry.is_file():
        try:
            document = json.loads(registry.read_text(encoding="utf-8"))
            plugins = document.get("plugins", {})
            for plugin_id, installs in plugins.items():
                if plugin_id in CLAUDE_PLUGIN_IDS:
                    marked_registry = True
                    break
                if any(
                    is_reachable_package_dir(Path(entry.get("installPath", "")))
                    for entry in installs
                    if isinstance(entry, dict)
                ):
                    marked_registry = True
                    break
        except (OSError, ValueError, AttributeError, TypeError) as exc:
            raise FullUninstallError("claude code plugin", f"cannot inspect {registry}: {exc}") from exc
    if not marked_registry and not marked_marketplace:
        return None
    claude = shutil.which("claude")
    if claude is None:
        raise FullUninstallError(
            "claude code plugin",
            f"{registry if marked_registry else marketplaces} has REACHABLE plugin evidence but "
            "the `claude` CLI is not on PATH, so the "
            "REACHABLE plugin cannot be unregistered; run "
            "`claude plugin uninstall reachable@reachable-local` from a shell that has it",
        )
    return claude


def holds_only_our_packages(entry: Path) -> bool:
    """An entry under `<marketplace>/plugins/` is ours in either layout.

    Directory-source marketplaces put the package there (`plugins/<pkg>`); the
    published GitHub marketplace nests it one level deeper
    (`plugins/claude-code/reachable`) -- the same two depths as
    `host_table` HOST_LOADED globs. Missing the nested layout left our own
    marketplace registered with its packages deleted (b260, G20/G21).
    """
    if is_reachable_package_dir(entry):
        return True
    nested = [child for child in entry.iterdir() if child.is_dir()]
    return bool(nested) and all(is_reachable_package_dir(child) for child in nested)


def our_claude_marketplaces(*, home: Path, timeout: float) -> List[Tuple[str, Path]]:
    """(name, install location) of every Claude Code marketplace holding only our plugins.

    Ours only when every plugin it holds is ours: removing a marketplace that
    also carries someone else's plugin would uninstall theirs. The host-plugin
    step removes these; the package-dir preview skips package dirs under them,
    because they are gone by the time that step runs.
    """
    claude = claude_cli(home)
    if claude is None:
        return []
    ours: List[Tuple[str, Path]] = []
    listing = json.loads(
        run_host_cli("claude code plugin", [claude, "plugin", "marketplace", "list", "--json"], timeout=timeout)
    )
    for marketplace in listing:
        location = Path(marketplace["installLocation"])
        plugins_dir = location / "plugins"
        children = [child for child in plugins_dir.iterdir() if child.is_dir()] if plugins_dir.is_dir() else []
        if children and all(holds_only_our_packages(child) for child in children):
            ours.append((marketplace["name"], location))
    return ours


def remove_claude_code_plugins(*, home: Path, act: bool, timeout: float) -> List[str]:
    step = "claude code plugin"
    claude = claude_cli(home)
    if claude is None:
        return []
    removed: List[str] = []
    # Before the uninstall: a directory-source marketplace lives outside
    # ~/.claude, so once installed_plugins.json drops us nothing names it.
    marketplaces = our_claude_marketplaces(home=home, timeout=timeout)
    plugins = json.loads(run_host_cli(step, [claude, "plugin", "list", "--json"], timeout=timeout))
    for plugin in plugins:
        if plugin["id"] not in CLAUDE_PLUGIN_IDS and not is_reachable_package_dir(Path(plugin["installPath"])):
            continue
        scope = plugin["scope"]
        cwd: Optional[Path] = None
        if scope in ("project", "local"):
            if "projectPath" not in plugin:
                raise FullUninstallError(
                    step,
                    f"{plugin['id']} is installed at {scope} scope with no projectPath in `claude plugin list --json`",
                )
            cwd = Path(plugin["projectPath"])
        elif scope != "user":
            raise FullUninstallError(step, f"{plugin['id']} has unknown scope {scope!r}")
        if act:
            run_host_cli(step, [claude, "plugin", "uninstall", plugin["id"], "--scope", scope], cwd=cwd, timeout=timeout)
        removed.append(f"claude code plugin {plugin['id']} ({scope})")

    for name, _location in marketplaces:
        if act:
            run_host_cli(step, [claude, "plugin", "marketplace", "remove", name], timeout=timeout)
        removed.append(f"claude code marketplace {name}")
    return removed


def remove_codex_plugins(*, home: Path, act: bool, timeout: float, edit_json: EditJson) -> List[str]:
    step = "codex plugin"
    # The `personal` marketplace file is written by the plugin installer and
    # may list other people's plugins too: only entries pointing at ours count.
    marketplace_json = home / ".agents" / "plugins" / "marketplace.json"
    ours_listed = False
    if marketplace_json.is_file():
        document = json.loads(marketplace_json.read_text(encoding="utf-8"))
        ours_listed = any(our_codex_catalog_entry(entry, home) for entry in document["plugins"])

    removed: List[str] = []
    codex = shutil.which("codex")
    if codex is not None:
        try:
            listing = json.loads(run_host_cli(step, [codex, "plugin", "list", "--json"], timeout=timeout))
        except FullUninstallError as exc:
            # Older Codex CLIs can be present without supporting plugin
            # commands. Our installer writes a local personal catalog; its
            # marked entries are removed below and its marked package by the
            # package-dir step. Unrelated CLI errors still stop.
            unsupported = (
                "unexpected argument 'list'" in str(exc)
                or "unrecognized subcommand 'plugin'" in str(exc)
            )
            if not unsupported:
                raise
            listing = {"installed": []}
        for plugin in listing["installed"]:
            if is_reachable_package_dir(Path(plugin["source"]["path"])):
                if act:
                    run_host_cli(step, [codex, "plugin", "remove", plugin["pluginId"]], timeout=timeout)
                removed.append(f"codex plugin {plugin['pluginId']}")
    if ours_listed:
        if act:
            # Re-read under the file's lock and drop only our entries: the
            # file lists other people's plugins, and it is the user's file
            # (mode kept). Review 2 item 5.
            def drop_ours(current: Any) -> Any:
                return {
                    **current,
                    "plugins": [entry for entry in current["plugins"] if not our_codex_catalog_entry(entry, home)],
                }

            edit_json(marketplace_json, drop_ours)
        removed.append(f"codex marketplace entry in {marketplace_json}")
    return removed


def our_codex_catalog_entry(entry: Any, home: Path) -> bool:
    """Match our marked package, or our installer's exact stale catalog path."""
    if not isinstance(entry, dict):
        return False
    source = entry.get("source")
    if not isinstance(source, dict) or not isinstance(source.get("path"), str):
        return False
    path = (home / source["path"]).resolve()
    if is_reachable_package_dir(path):
        return True
    return entry.get("name") == "reachable" and path == (home / ".agents/plugins/plugins/reachable").resolve()


# -------------------------------------------------------- U3.5 package directories


def remove_package_dirs(
    *,
    home: Path,
    parents: Tuple[Path, ...],
    link_roots: Tuple[Path, ...],
    act: bool,
    removed_by_host_cli: Tuple[Path, ...],
) -> List[str]:
    """Delete every marked package/overlay dir that is a child of `parents`, and links into them.

    `parents` may hold `*` segments (`marketplaces/*/plugins`), expanded here.
    `removed_by_host_cli`: marketplace locations the host-plugin step removes
    first; the preview does not list package dirs under them. When acting they
    no longer exist, so the caller passes `()`.
    """
    removed_dirs: List[Path] = []
    emptied: List[Path] = []
    for parent in parents:
        # The fixed part of the pattern (`.claude/plugins/cache` of `cache/*/*`):
        # folders below it that held only our package go with it (J4 left an empty
        # `cache/sthenos-security`, INSTALLER-JOURNEY run 44406868226).
        rel = parent.relative_to(home)
        fixed = home.joinpath(*[part for part in rel.parts[: next(
            (i for i, part in enumerate(rel.parts) if "*" in part), len(rel.parts))]])
        for directory in sorted(home.glob(str(rel))):
            if not directory.is_dir():
                continue
            if any(directory == root or root in directory.parents for root in removed_by_host_cli):
                continue
            gone = set()
            for child in sorted(directory.iterdir()):
                if not child.is_symlink() and is_reachable_package_dir(child):
                    if act:
                        shutil.rmtree(child)
                    removed_dirs.append(child)
                    gone.add(child)
            # The same answer for a preview and a run: a folder goes when all it
            # held was going (the preview lists exactly what the run removes).
            folder = directory
            while gone and folder != fixed and fixed in folder.parents and folder.is_dir() and all(
                entry in gone for entry in folder.iterdir()
            ):
                if act:
                    folder.rmdir()
                emptied.append(folder)
                gone = {folder}
                folder = folder.parent
    removed = [f"package dir {path}" for path in removed_dirs]
    removed.extend(f"empty folder {path}" for path in emptied)
    # Skill links `install-plugin.sh` makes into a package dir (devin).
    for root in link_roots:
        if not root.is_dir():
            continue
        for link in sorted(root.iterdir()):
            if not link.is_symlink():
                continue
            target = Path(os.readlink(link))
            if not target.is_absolute():
                target = link.parent / target
            if any(target == path or path in target.parents for path in removed_dirs):
                if act:
                    link.unlink()
                removed.append(f"skill link {link}")
    return removed


def ledgered_skill_roots(ledger_path: Path) -> List[str]:
    """The skill roots the skills ledger records we copied into (none without a ledger)."""
    if not ledger_path.is_file():
        return []
    return sorted(json.loads(ledger_path.read_text(encoding="utf-8"))["roots"])


def is_shipped_copy(skill_dir: Path, digests: frozenset) -> bool:
    """True when `skill_dir` is exactly one `SKILL.md` that an earlier pack shipped."""
    if skill_dir.is_symlink() or not skill_dir.is_dir():
        return False
    entries = sorted(p.relative_to(skill_dir).as_posix() for p in skill_dir.rglob("*"))
    if entries != ["SKILL.md"]:
        return False
    skill_md = skill_dir / "SKILL.md"
    if skill_md.is_symlink() or not skill_md.is_file():
        return False
    return hashlib.sha256(skill_md.read_bytes()).hexdigest() in digests


def withdrawn_skills_in(
    skills_root: Path, withdrawn: Dict[str, frozenset], *, act: bool
) -> Tuple[List[Path], List[Path]]:
    """(removed, left): our exact copies of withdrawn skills go; anything else is left and reported."""
    removed: List[Path] = []
    left: List[Path] = []
    for name, digests in withdrawn.items():
        skill_dir = skills_root / name
        if not (skill_dir.exists() or skill_dir.is_symlink()):
            continue
        if is_shipped_copy(skill_dir, digests):
            if act:
                shutil.rmtree(skill_dir)
            removed.append(skill_dir)
        else:
            left.append(skill_dir)
    return removed, left


def remove_ledgered_skills(
    *, ledger_path: Path, names: Tuple[str, ...], withdrawn: Dict[str, frozenset], act: bool
) -> List[str]:
    """Gate 1 skills copied into hosts with no package format, from the roots the ledger records."""
    removed: List[str] = []
    for root in ledgered_skill_roots(ledger_path):
        for name in names:
            skill_dir = Path(root) / name
            if skill_dir.is_dir():
                if act:
                    shutil.rmtree(skill_dir)
                removed.append(f"skill {skill_dir}")
        gone, _left = withdrawn_skills_in(Path(root), withdrawn, act=act)
        removed.extend(f"skill {skill_dir}" for skill_dir in gone)
    return removed


# ------------------------------------------------------------ U3.6 user-level tells


def strip_managed_hook_entries(hooks: Dict[str, Any]) -> int:
    """Drop `_reach_gate1_managed` entries from every event; return the count."""
    dropped = 0
    for event in list(hooks):
        entries = hooks[event]
        if not isinstance(entries, list):
            continue
        kept = [e for e in entries if not (isinstance(e, dict) and e.get(GATE1_MANAGED_KEY))]
        dropped += len(entries) - len(kept)
        if kept:
            hooks[event] = kept
        else:
            del hooks[event]
    return dropped


def remove_hook_tells(*, files: Tuple[Path, ...], act: bool, lock: Lock, write_bytes: WriteBytes) -> List[str]:
    """Our `_reach_gate1_managed` hook entries in each user hook file; the rest is the user's."""
    removed: List[str] = []
    for path in files:
        if not path.is_file():
            continue
        with lock(path):
            text = path.read_text(encoding="utf-8")
            if not text.strip():
                continue
            # Unparseable is the user's file in a state we cannot edit safely:
            # json.loads raises and the command stops, naming nothing removed yet.
            document = json.loads(text)
            hooks = document.get("hooks")
            if not isinstance(hooks, dict):
                continue
            if strip_managed_hook_entries(hooks):
                if act:
                    if not hooks:
                        del document["hooks"]
                    write_bytes(path, (json.dumps(document, indent=2, default=str) + "\n").encode("utf-8"))
                removed.append(f"gate 1 hooks in {path}")
    return removed


def block_digest(block_text: str) -> str:
    """The digest recorded for a managed block when it was written."""
    return hashlib.sha256(block_text.encode("utf-8")).hexdigest()


def removable_block(
    existing: str, *, path: Path, begin: str, end: str, last_sha256: Optional[str]
) -> Optional[Tuple[int, int]]:
    """(begin index, end index) of our block in `existing`, or None when absent.

    Raises ManagedBlockConflict for duplicate or unbalanced markers, or a
    block edited after we wrote it (`last_sha256`: the digest recorded then).
    """
    if existing.count(begin) > 1 or existing.count(end) > 1:
        raise ManagedBlockConflict(
            f"managed_block_conflict: {path} has duplicate reachable markers; "
            "refusing to guess which block to remove"
        )
    begin_i = existing.find(begin)
    end_i = existing.find(end)
    if begin_i == -1 and end_i == -1:
        return None
    if (begin_i == -1) != (end_i == -1):
        raise ManagedBlockConflict(
            f"managed_block_conflict: {path} has an unbalanced reachable block; "
            "remove it by hand"
        )
    old_block = existing[begin_i : end_i + len(end)]
    if last_sha256 is not None and block_digest(old_block + "\n") != last_sha256:
        raise ManagedBlockConflict(
            f"managed_block_conflict: {path}'s reachable block was edited after "
            "we wrote it; refusing to delete those edits -- remove it by hand"
        )
    return begin_i, end_i


def without_block(existing: str, begin_i: int, end_i: int, end: str) -> str:
    """`existing` with our block (and the newline after it) cut out."""
    after = existing[end_i + len(end) :]
    if after.startswith("\n"):
        after = after[1:]
    return existing[:begin_i] + after


def recorded_block_digest(state_path: Path, path: Path) -> Optional[str]:
    """The digest the managed-blocks record holds for `path` (None: never recorded)."""
    if not state_path.is_file():
        return None
    payload = json.loads(state_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("blocks"), dict):
        raise ValueError(f"{state_path}: managed-blocks state is not {{'blocks': {{...}}}}")
    return payload["blocks"].get(str(path), {}).get("sha256")


# ------------------------------------------------------------- marked spans (U10)

#: Begin/end markers of the spans setup writes into a file that is not ours
#: (design "Two Uninstalls" U10). The begin marker is the anchor the record keeps.
MCP_BEGIN = "# BEGIN REACHABLE MCP -- managed by REACHABLE, removed by reachable uninstall"
MCP_END = "# END REACHABLE MCP"
RULES_BEGIN = "<!-- BEGIN REACHABLE RULES -- managed by REACHABLE, removed by reachable uninstall -->"
RULES_END = "<!-- END REACHABLE RULES -->"
#: The record's key in `managed-blocks.json` (beside the Gate 1 `blocks`).
FILES_KEY = "files"
#: The record's key for the folders setup created for those files.
FOLDERS_KEY = "folders"
#: The record's key for MCP registrations made through a host CLI.
REGISTRATIONS_KEY = "registrations"
#: What a marked file is written in; "json" is re-parsed after a cut (U10).
SPAN_SYNTAXES: Tuple[str, ...] = ("json", "toml", "yaml", "text")
#: `<file>.reachable-backup-<UTC stamp>`: the copy taken before a change.
BACKUP_INFIX = ".reachable-backup-"


def span_digest(text: str) -> str:
    """sha256 of a span (or of what surrounds the spans), as the record keeps it."""
    return hashlib.sha256(text.encode("utf-8", "surrogateescape")).hexdigest()


def read_text_exact(path: Path) -> str:
    """The file's text with every byte kept (`newline=""`: no CRLF translation)."""
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as handle:
        return handle.read()


def text_bytes(text: str) -> bytes:
    return text.encode("utf-8", "surrogateescape")


def load_span_records(state_path: Path) -> Dict[str, Any]:
    """`managed-blocks.json`'s `files` record (empty when setup never recorded one)."""
    if not state_path.is_file():
        return {}
    payload = json.loads(state_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get(FILES_KEY, {}), dict):
        raise ValueError(f"{state_path}: managed-blocks state has no {FILES_KEY!r} mapping")
    return payload.get(FILES_KEY, {})


def load_created_folders(state_path: Path) -> List[str]:
    if not state_path.is_file():
        return []
    folders = json.loads(state_path.read_text(encoding="utf-8")).get(FOLDERS_KEY, [])
    if not isinstance(folders, list):
        raise ValueError(f"{state_path}: managed-blocks state {FOLDERS_KEY!r} is not a list")
    return [str(folder) for folder in folders]


def load_registrations(state_path: Path) -> List[Dict[str, Any]]:
    if not state_path.is_file():
        return []
    payload = json.loads(state_path.read_text(encoding="utf-8"))
    registrations = payload.get(REGISTRATIONS_KEY, [])
    if not isinstance(registrations, list):
        raise ValueError(f"{state_path}: managed-blocks state {REGISTRATIONS_KEY!r} is not a list")
    return registrations


class SpanEdited(ManagedBlockConflict):
    """A marked span is there but its bytes differ from what setup wrote."""


#: What `cut_spans` found for one file.
SPANS_REMOVED, SPANS_GONE, FILE_IS_OURS = "removed", "gone", "ours"


def cut_spans(text: str, record: Dict[str, Any], *, path: Path) -> Tuple[str, str]:
    """(`text` without our recorded spans, outcome).

    Each span is found at its anchor and must hash to the recorded digest.
    An anchor present with no matching span raises SpanEdited: the user edited
    inside the markers, and nothing in the file is removed. A file recorded as
    ours whole is FILE_IS_OURS only when its digest matches.
    """
    if record.get("owned"):
        if span_digest(text) != record["rest_sha256"]:
            raise SpanEdited(f"{path}: the REACHABLE file was edited after setup wrote it")
        return "", FILE_IS_OURS
    taken: List[Tuple[int, int]] = []
    for span in record["spans"]:
        anchor, offset, length = span["anchor"], int(span["offset"]), int(span["length"])
        hit: Optional[int] = None
        anchor_seen = False
        at = text.find(anchor)
        while at != -1:
            anchor_seen = True
            start = at - offset
            overlaps = any(start < end and s < start + length for s, end in taken)
            if start >= 0 and not overlaps and span_digest(text[start : start + length]) == span["sha256"]:
                hit = start
                break
            at = text.find(anchor, at + 1)
        if hit is not None:
            taken.append((hit, hit + length))
        elif anchor_seen:
            raise SpanEdited(f"{path}: the REACHABLE entry was edited after setup wrote it")
    if not taken:
        return text, SPANS_GONE
    for start, end in sorted(taken, reverse=True):
        text = text[:start] + text[end:]
        if record["syntax"] == "json":
            text = _drop_comma_left_for_us(text, start)
    if record["syntax"] == "json" and text.strip():
        try:
            json.loads(text)
        except ValueError as exc:
            # The user edited next to our line (a comma after it, say): cutting
            # it would leave a file their host cannot read.
            raise SpanEdited(f"{path}: removing the REACHABLE entry would leave invalid JSON ({exc})") from exc
    return text, SPANS_REMOVED


def _drop_comma_left_for_us(text: str, at: int) -> str:
    """After our JSON line is cut at `at`: a comma the user put before it, now
    followed by the end of the object or array, is dropped -- it separated
    their member from ours, and JSON allows no trailing comma."""
    before = at
    while before > 0 and text[before - 1] in " \t\r\n":
        before -= 1
    after = at
    while after < len(text) and text[after] in " \t\r\n":
        after += 1
    if before > 0 and text[before - 1] == "," and after < len(text) and text[after] in "}]":
        return text[: before - 1] + text[before:]
    return text


def prune_created_folders(folders: List[str], *, act: bool) -> List[str]:
    """The folders setup created that are empty now, deepest first; a folder
    holding anything (the user's files) is kept. Returns those removed."""
    removed: List[str] = []
    for name in sorted(set(folders), key=lambda f: (-len(Path(f).parts), f)):
        folder = Path(name)
        if not folder.is_dir() or any(p for p in folder.iterdir() if str(p) not in removed):
            continue
        if act:
            folder.rmdir()
        removed.append(name)
    return removed


def remove_marked_entries(
    records: Dict[str, Any],
    *,
    act: bool,
    lock: Lock,
    write_bytes: WriteBytes,
    only: Optional[Tuple[Path, ...]] = None,
) -> Tuple[List[str], List[str], List[str]]:
    """Cut every recorded span out of its file (U10): (removed, warnings, done paths).

    A file left holding only what setup created around the spans is deleted.
    A span edited by the user leaves its file unchanged and is a warning. `only` limits the run to those files (one agent's uninstall).
    """
    removed: List[str] = []
    warnings: List[str] = []
    done: List[str] = []
    wanted = None if only is None else {str(p) for p in only}
    for name in sorted(records):
        if wanted is not None and name not in wanted:
            continue
        record = records[name]
        path = Path(name)
        if not path.is_file():
            done.append(name)
            continue
        with lock(path):
            text = read_text_exact(path)
            try:
                rest, outcome = cut_spans(text, record, path=path)
            except SpanEdited as exc:
                warnings.append(f"warning: {exc}; left unchanged, remove it by hand")
                continue
            done.append(name)
            if outcome == SPANS_GONE:
                continue
            delete = outcome == FILE_IS_OURS or (record.get("created") and span_digest(rest) == record["rest_sha256"])
            if delete:
                removed.append(f"{path} (created by setup)")
                if act:
                    path.unlink()
                continue
            # No new backup here: the file comes back to the bytes setup found,
            # which setup's own backup next to it holds; a backup taken now
            # would keep our entry (an MCP bearer token, say) on disk after
            # uninstall.
            if act:
                write_bytes(path, text_bytes(rest))
                if record.get("restore_mode") is not None:
                    os.chmod(path, int(record["restore_mode"]))
            removed.append(f"REACHABLE entries in {path}")
    return removed, warnings, done


# ------------------------------------------------------------- installer PATH line


def remove_installer_path_lines(*, home: Path, act: bool, write_bytes: WriteBytes) -> List[str]:
    """The installer's PATH line and its marker, from each shell startup file.

    Only those two exact lines (and the blank line the installer wrote before
    the marker); everything else in the file is the user's and is kept. Left
    in place, every new shell put a deleted folder on PATH."""
    removed: List[str] = []
    for name in SHELL_STARTUP_FILES:
        startup = home / name
        if not startup.is_file():
            continue
        try:
            lines = startup.read_text(encoding="utf-8", errors="surrogateescape").splitlines(keepends=True)
        except OSError as exc:
            raise FullUninstallError("shell PATH line", f"cannot read {startup}: {exc}") from exc
        kept: List[str] = []
        for line in lines:
            text = line.rstrip("\r\n")
            if text == INSTALLER_PATH_MARKER:
                if kept and not kept[-1].strip():
                    kept.pop()
                continue
            if text == INSTALLER_PATH_LINE:
                continue
            kept.append(line)
        if len(kept) == len(lines):
            continue
        if act:
            try:
                write_bytes(startup, "".join(kept).encode("utf-8", errors="surrogateescape"))
            except OSError as exc:
                raise FullUninstallError("shell PATH line", f"cannot write {startup}: {exc}") from exc
        removed.append(f"REACHABLE PATH line in {startup}")
    return removed


# ------------------------------------------------------------ U3.9 data directories


#: What uninstall keeps in `~/.reachable-cache` (Al, 2026-11-18: "ledger should
#: survive"): the governance audit ledger and its signing key, which is also the
#: air-gap enclave key registered with Sthenos. A reinstall continues the same
#: chain from the same path. Everything else there is a rebuildable cache.
LEGACY_CACHE_KEPT = ("audit-logs",)
KEPT_NOTE = "kept: your audit trail and its signing key (delete that folder yourself if you don't need them)"


def remove_reachable_dirs(
    dirs: Tuple[Path, ...], *, act: bool, kept: Dict[Path, Tuple[str, ...]]
) -> List[str]:
    """REACHABLE_HOME and every other directory REACHABLE owns outright.

    `kept`: a directory -> the names inside it that stay; the rest of it goes."""
    removed: List[str] = []
    seen = set()
    for directory in dirs:
        if directory in seen:
            continue
        seen.add(directory)
        keep = kept.get(directory, ())
        if keep and directory.is_dir() and not directory.is_symlink() and any(
            (directory / name).exists() for name in keep
        ):
            for child in sorted(directory.iterdir()):
                if child.name in keep:
                    continue
                if act:
                    if child.is_dir() and not child.is_symlink():
                        shutil.rmtree(child)
                    else:
                        child.unlink()
                removed.append(str(child))
            removed.extend(f"{directory / name} -- {KEPT_NOTE}" for name in keep if (directory / name).exists())
            continue
        if directory.is_symlink() or directory.is_file():
            if act:
                directory.unlink()
        elif directory.is_dir():
            if act:
                shutil.rmtree(directory)
        else:
            continue
        removed.append(str(directory))
    return removed


def app_dir_candidates(
    app_names: Tuple[str, ...], *, home: Path, platform: str, env: Dict[str, str], uid: int, tmp: str
) -> Tuple[Path, ...]:
    """Every directory the daemon's app folders (`reach_agent.state.app_dirs`) can resolve to.

    platformdirs picks the real one at run time; with no runtime there is no
    platformdirs, so this lists every place its rules can pick, each named for
    our app (one that does not exist is skipped). Linux's log dir is
    `<state>/<app>/log`: the app-named parent is listed, so nothing empty is
    left. `test_uninstall_footprint` checks that this set covers `app_dirs()`.
    `REACH_VIBE_HOME` replaces the platform folders, as in `state._override_root`.
    The design names `~/.config/reach-agent` (the MCP bearer secret) on every
    platform, so `~/.config/<app>` is always listed.
    """
    named = tuple(home / ".config" / name for name in app_names)
    override = env.get("REACH_VIBE_HOME")
    if override:
        return tuple(sorted({Path(override).expanduser(), *named}))
    bases: List[Path] = []
    if platform == "darwin":
        library = home / "Library"
        bases = [library / "Caches" / "TemporaryItems", library / "Caches", library / "Logs",
                 library / "Application Support"]
    elif platform.startswith("linux"):
        for var, default in (("XDG_CACHE_HOME", home / ".cache"), ("XDG_CONFIG_HOME", home / ".config"),
                             ("XDG_STATE_HOME", home / ".local" / "state")):
            bases.append(default)
            if env.get(var) and os.path.isabs(env[var]):
                bases.append(Path(env[var]))
        bases.append(Path("/run/user") / str(uid))
        bases.append(Path(tmp) / f"runtime-{uid}")
        if env.get("XDG_RUNTIME_DIR") and os.path.isabs(env["XDG_RUNTIME_DIR"]):
            bases.append(Path(env["XDG_RUNTIME_DIR"]))
    else:
        raise FullUninstallError("delete REACHABLE data", f"no app-folder rules for platform {platform!r}")
    return tuple(sorted({*(base / name for base in bases for name in app_names), *named}))


# ======================================================== U9: run with no runtime

LAYOUT_FILE = "uninstall-layout.json"
NO_RUNTIME_NOTE = "The REACHABLE runtime is missing or broken, so this uninstall runs without it (U9)."
#: Exit codes of the no-runtime run: done; stopped or something left; usage refused.
EXIT_DONE, EXIT_NOT_DONE, EXIT_USAGE = 0, 1, 2


def sidecar_lock(path: Path, *, wait_seconds: float, poll_seconds: float) -> ContextManager[None]:
    """A lock beside the user's file while it is read and rewritten; removed after.

    Waits at most `wait_seconds` (the runtime's `file_lock_seconds`, shipped
    in the layout), then raises FullUninstallError naming the file.
    """

    @contextlib.contextmanager
    def held() -> Iterator[None]:
        lock_path = path.with_name(f".{path.name}.reachable-uninstall.lock")
        with open(lock_path, "w", encoding="utf-8") as handle:
            deadline = time.monotonic() + wait_seconds
            while True:
                try:
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError as exc:
                    if time.monotonic() >= deadline:
                        raise FullUninstallError(
                            "file lock", f"{path} stayed locked for {wait_seconds}s; nothing in it was changed"
                        ) from exc
                    time.sleep(poll_seconds)
            try:
                yield
            finally:
                fcntl.flock(handle, fcntl.LOCK_UN)
                lock_path.unlink()

    return held()


def _write_bytes_keep_mode(path: Path, data: bytes) -> None:
    mode = path.stat().st_mode & 0o7777
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise



#: One process: (parent pid, real uid, argv). Without /proc, argv is the one
#: `ps` command string, so matching treats argv[0] as "the start of the line".
ProcessRow = Tuple[int, int, List[str]]


def process_table(*, timeout: float) -> Dict[int, ProcessRow]:
    """Every process this user can see: /proc on Linux, `ps` elsewhere (stdlib only)."""
    table: Dict[int, ProcessRow] = {}
    proc = Path("/proc")
    if sys.platform.startswith("linux") and proc.is_dir():
        for entry in proc.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                raw = (entry / "cmdline").read_bytes()
                status = (entry / "status").read_text(encoding="utf-8")
            except (FileNotFoundError, ProcessLookupError, PermissionError):
                # The process exited between the listing and the read, or it is
                # another user's: either way it is not a process of ours to stop.
                continue
            fields = dict(line.split(":", 1) for line in status.splitlines() if ":" in line)
            argv = [part for part in raw.decode("utf-8", "replace").split("\0") if part]
            table[int(entry.name)] = (int(fields["PPid"].split()[0]), int(fields["Uid"].split()[0]), argv)
        return table
    listing = subprocess.run(
        ["ps", "-axww", "-o", "pid=,ppid=,uid=,command="],
        capture_output=True, text=True, timeout=timeout, check=True,
    ).stdout
    for line in listing.splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4:
            table[int(parts[0])] = (int(parts[1]), int(parts[2]), [parts[3]])
    return table


def runs_from(argv: List[str], venv: Path) -> bool:
    """True when argv[0] or argv[1] (the interpreter or reachctl) is inside `venv`.

    The venv may already be deleted (a broken runtime), so paths are compared
    as text, against the venv as given and as it resolves."""
    prefixes = {f"{venv}/", f"{venv.resolve(strict=False)}/"}
    if len(argv) == 1:  # a `ps` command string
        line = argv[0]
        return any(line.startswith(p) or line.split(" ", 1)[-1].startswith(p) for p in prefixes)
    return any(arg.startswith(p) for arg in argv[:2] for p in prefixes)


#: `<python> -m reach_agent [options] _daemon ...`, as whole arguments: a
#: substring match took a pytest run of tests/reach_agent/test_*_daemon_*.py
#: for the daemon and stopped it (found 2026-11-18 by this suite).
_DAEMON_COMMAND = re.compile(r"(?:^|\s)-m\s+reach_agent(?:\s+-\S+)*\s+_daemon(?:\s|$)")


def is_daemon_command(argv: List[str]) -> bool:
    """True when argv runs the REACHABLE daemon entry point."""
    return _DAEMON_COMMAND.search(" ".join(argv)) is not None


class ProcessState(enum.Enum):
    """What `os.kill(pid, 0)` and the process state say about a pid. Each
    caller decides what each state means; none is a quiet default."""

    GONE = "gone"  # exited, or a zombie (exited; only its parent can reap it)
    RUNNING = "running"
    OTHER_USER = "running as another user"  # we may not signal it


def _signal_probe(pid: int) -> ProcessState:
    """`os.kill(pid, 0)`: no such process, another user's, or alive."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return ProcessState.GONE
    except PermissionError:
        return ProcessState.OTHER_USER
    return ProcessState.RUNNING


def _proc_state(stat: Path) -> ProcessState:
    """From /proc/<pid>/stat: a zombie has exited; the file vanishing means the
    process exited between the signal probe and this read."""
    try:
        text = stat.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ProcessState.GONE
    return ProcessState.GONE if text.rsplit(")", 1)[1].split()[0] == "Z" else ProcessState.RUNNING


def process_state(pid: int, *, timeout: float) -> ProcessState:
    """GONE, RUNNING or OTHER_USER for `pid` (stdlib only: /proc or `ps`)."""
    probed = _signal_probe(pid)
    if probed is not ProcessState.RUNNING:
        return probed
    if sys.platform.startswith("linux") and Path("/proc").is_dir():
        return _proc_state(Path(f"/proc/{pid}/stat"))
    letter = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True,
                            timeout=timeout, check=False).stdout.strip()[:1]
    return ProcessState.GONE if letter in ("", "Z") else ProcessState.RUNNING


def _not_ours_to_signal(pid: int, where: str) -> FullUninstallError:
    return FullUninstallError(
        "stop REACHABLE processes",
        f"pid {pid} ({where}) runs as another user, so uninstall may not stop it; "
        "stop it yourself, then run uninstall again. Nothing was removed",
    )


def reachable_processes(
    *, venv: Path, pidfiles: Tuple[Path, ...], timeout: float
) -> List[List[Tuple[int, str]]]:
    """This installation's processes, in the order they are stopped.

    Two groups, each with every descendant: remediation first (the only one
    that edits the user's code), then the rest (scans, the daemon, MCP
    servers, hook checks). A process is ours when its user is ours and it runs
    from this installation's venv. A daemon pid file naming a live process
    that is not ours is refused, as before: that pid may have been reused."""
    me = os.getpid()
    uid = os.getuid()
    table = process_table(timeout=timeout)
    roots = {pid for pid, (_pp, owner, argv) in table.items()
             if pid != me and owner == uid and runs_from(argv, venv)}
    for pidfile in (p for p in pidfiles if p.is_file()):
        pid_text = pidfile.read_text(encoding="utf-8").strip()
        if not pid_text.isdigit():
            raise FullUninstallError("stop REACHABLE processes", f"{pidfile} holds {pid_text[:20]!r}, not a process id")
        pid = int(pid_text)
        if pid in roots:
            continue
        state = process_state(pid, timeout=timeout)
        if state is ProcessState.GONE:
            continue
        if state is ProcessState.OTHER_USER:
            raise _not_ours_to_signal(pid, str(pidfile))
        # macOS shows a venv Python as the framework binary it runs, so the
        # daemon's argv is `.../Python -m reach_agent ... _daemon` with no venv
        # path in it (measured 2026-11-18). The pid file is this installation's,
        # so a daemon command line owned by this user is ours.
        row = table.get(pid)
        if row is not None and row[1] == uid and is_daemon_command(row[2]):
            roots.add(pid)
        else:
            raise FullUninstallError(
                "stop REACHABLE processes",
                f"pid {pid} ({pidfile}) is running but is not this installation's REACHABLE daemon; "
                "stop it yourself, then run uninstall again. Nothing was removed",
            )
    children: Dict[int, List[int]] = {}
    for pid, (ppid, owner, _argv) in table.items():
        if owner == uid:
            children.setdefault(ppid, []).append(pid)

    def with_descendants(start: List[int]) -> List[int]:
        seen: List[int] = []
        todo = list(start)
        while todo:
            pid = todo.pop()
            if pid in seen or pid == me:
                continue
            seen.append(pid)
            todo.extend(children.get(pid, []))
        return seen

    remediation = sorted(p for p in roots if any("remediat" in arg for arg in table[p][2]))
    first = with_descendants(remediation)
    rest = [p for p in with_descendants(sorted(roots - set(remediation))) if p not in first]
    describe = lambda pid: f"pid {pid}: {' '.join(table[pid][2])[:120]}"  # noqa: E731
    return [[(p, describe(p)) for p in group] for group in (first, rest) if group]


def stop_processes(pids: List[int], *, grace: float, reap: float, poll: float, timeout: float) -> None:
    """SIGTERM, wait up to `grace`; SIGKILL what is left, wait up to `reap`; raise if any survives.

    A pid running as another user is refused by name before any signal is sent."""
    import signal

    def still_running() -> List[int]:
        states = {p: process_state(p, timeout=timeout) for p in pids}
        for pid, state in states.items():
            if state is ProcessState.OTHER_USER:
                raise _not_ours_to_signal(pid, "a child of a REACHABLE process")
        return [p for p, state in states.items() if state is ProcessState.RUNNING]

    for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, reap)):
        alive = still_running()
        if not alive:
            return
        for pid in alive:
            try:
                os.kill(pid, sig)
            except ProcessLookupError:
                continue  # exited after the check: nothing left to signal
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline and still_running():
            time.sleep(poll)
    survivors = still_running()
    if survivors:
        raise FullUninstallError("stop REACHABLE processes", f"pids {survivors} did not exit after SIGKILL")


#: Workspace files setup wires (footprint table "workspace files"), and the
#: words that mean REACHABLE put an entry in one.
WORKSPACE_WIRING_FILES = (".claude/settings.json", ".mcp.json", ".cursor/mcp.json", ".cursor/hooks.json")
REACHABLE_WIRING_WORDS = ("reachctl", "reach_agent", "reachable-hook", "reachable-mcp", '"reachable"')


def unrecorded_workspace_wiring(workspace: Path, recorded: Tuple[Path, ...]) -> List[Path]:
    """Wiring files in `workspace` that name REACHABLE and that no span record covers."""
    found: List[Path] = []
    for rel in WORKSPACE_WIRING_FILES:
        path = workspace / rel
        if not path.is_file() or path.resolve() in recorded or path in recorded:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if any(word in text for word in REACHABLE_WIRING_WORDS):
            found.append(path)
    return found


class NoRuntimeUninstall:
    """The U9 run: the U3 steps that need no runtime, in U3 order, from the shipped layout."""

    def __init__(self, layout: Dict[str, Any], *, home: Path, reachable_home: Path, env: Dict[str, str]) -> None:
        self.layout = layout
        self.home = home
        self.reachable_home = reachable_home
        self.timeout = float(layout["host_cli_timeout_seconds"])
        wait, poll = float(layout["file_lock_seconds"]), float(layout["file_lock_poll_seconds"])
        self.lock: Lock = lambda path: sidecar_lock(path, wait_seconds=wait, poll_seconds=poll)
        self.app_names: Tuple[str, ...] = tuple(layout["app_names"])
        self.app_dirs = app_dir_candidates(
            self.app_names, home=home, platform=sys.platform, env=env, uid=os.getuid(), tmp=tempfile.gettempdir()
        )
        #: Edited marked entries found by the last listing or run, left unchanged.
        self.warnings: List[str] = []

    def _rel(self, key: str) -> Tuple[Path, ...]:
        return tuple(self.home / rel for rel in self.layout[key])

    def _in_app_dirs(self, name_of: Callable[[str], str]) -> Tuple[Path, ...]:
        """`<app dir>/<file>` and, under REACH_VIBE_HOME, `<root>/{runtime,config}/<file>`."""
        found = []
        for d in self.app_dirs:
            for app in self.app_names:
                for parent in (d, d / "runtime", d / "config"):
                    found.append(parent / name_of(app))
        return tuple(found)

    def _stop_processes(self, act: bool) -> List[str]:
        """This installation's processes and their children: listed, or stopped in order."""
        groups = reachable_processes(
            venv=self.reachable_home / "venv", pidfiles=self.daemon_pidfiles(), timeout=self.timeout
        )
        if act:
            for group in groups:
                stop_processes(
                    [pid for pid, _ in group],
                    grace=float(self.layout["process_terminate_grace_seconds"]),
                    reap=float(self.layout["process_reap_seconds"]),
                    poll=float(self.layout["process_poll_seconds"]),
                    timeout=self.timeout,
                )
        return [description for group in groups for _pid, description in group]

    def daemon_pidfiles(self) -> Tuple[Path, ...]:
        """`<runtime dir>/<app>.pid` (`state.DaemonPaths`)."""
        return self._in_app_dirs(lambda app: f"{app}.pid")

    def wired_workspaces(self) -> List[str]:
        """The wired-workspace registry (`state.watched_workspaces_path`), read before its folder goes."""
        found: List[str] = []
        for candidate in self._in_app_dirs(lambda app: f"{app}-watched-workspaces.json"):
            if candidate.is_file():
                found.extend(json.loads(candidate.read_text(encoding="utf-8")))
        return sorted(set(found))

    def _edit_json(self, path: Path, change: Callable[[Any], Any]) -> None:
        with self.lock(path):
            document = change(json.loads(path.read_text(encoding="utf-8")))
            _write_bytes_keep_mode(path, (json.dumps(document, indent=2) + "\n").encode("utf-8"))

    def _managed_blocks(self, act: bool) -> List[str]:
        state = self.reachable_home / self.layout["managed_blocks_state"]
        removed: List[str] = []
        for entry in self.layout["managed_block_files"]:
            path = (self.home / entry["path"]).resolve()
            if not path.is_file():
                continue
            with self.lock(path):
                existing = path.read_text(encoding="utf-8")
                found = removable_block(existing, path=path, begin=entry["begin"], end=entry["end"],
                                        last_sha256=recorded_block_digest(state, path))
                if found is None:
                    continue
                if act:
                    updated = without_block(existing, found[0], found[1], entry["end"])
                    if updated.strip():
                        _write_bytes_keep_mode(path, updated.encode("utf-8"))
                    else:
                        path.unlink()
                removed.append(f"gate 1 block in {path}")
        return removed

    def steps(self) -> List[Tuple[str, Step]]:
        layout, home = self.layout, self.home
        parents, link_roots = self._rel("plugin_parent_dirs"), self._rel("skill_link_roots")
        data_dirs = (self.reachable_home, *self._rel("data_dirs"), *self.app_dirs)
        withdrawn = {name: frozenset(d) for name, d in layout["withdrawn_skills"].items()}

        def packages(act: bool) -> List[str]:
            by_cli = () if act else tuple(loc for _n, loc in our_claude_marketplaces(home=home, timeout=self.timeout))
            return remove_package_dirs(home=home, parents=parents, link_roots=link_roots, act=act,
                                       removed_by_host_cli=by_cli)

        return [
            # Remediation first, then scans, the daemon and MCP servers, each with
            # its children; again before the data goes, for a server the host
            # restarted meanwhile (the runtime path's order, cli._full_uninstall_steps).
            ("stop REACHABLE processes", self._stop_processes),
            ("unregister agent plugins", lambda act: [
                *remove_claude_code_plugins(home=home, act=act, timeout=self.timeout),
                *remove_codex_plugins(home=home, act=act, timeout=self.timeout, edit_json=self._edit_json),
            ]),
            ("delete plugin packages", packages),
            ("delete copied skills", lambda act: remove_ledgered_skills(
                ledger_path=self.reachable_home / layout["skills_ledger"],
                names=tuple(layout["gate1_skill_names"]), withdrawn=withdrawn, act=act)),
            ("remove user-level hooks", lambda act: [
                *remove_hook_tells(files=self._rel("hook_tell_files"), act=act, lock=self.lock,
                                   write_bytes=_write_bytes_keep_mode),
                *self._managed_blocks(act),
            ]),
            ("remove the installer's PATH line", lambda act: remove_installer_path_lines(
                home=home, act=act, write_bytes=_write_bytes_keep_mode)),
            ("remove MCP registrations", self._registrations),
            ("remove marked MCP entries and workspace wiring", self._marked_entries),
            ("stop REACHABLE processes started meanwhile", self._stop_processes),
            ("delete REACHABLE data", lambda act: remove_reachable_dirs(
                data_dirs, act=act, kept={home / rel: tuple(names) for rel, names in layout["kept_on_uninstall"].items()})),
        ]

    def _state(self) -> Path:
        return self.reachable_home / self.layout["managed_blocks_state"]

    def _registrations(self, act: bool) -> List[str]:
        """Host-CLI MCP registrations setup recorded (U10: Claude Code's `claude mcp add`)."""
        removed: List[str] = []
        for registration in load_registrations(self._state()):
            cli, name = str(registration["cli"]), str(registration["name"])
            # `claude mcp get <absent>` exits 0 and prints "No MCP server named";
            # presence is its `Type:` line (the runtime's `_claude_get_transport`).
            listing = run_host_cli("remove MCP registrations", [cli, "mcp", "get", name],
                                   timeout=self.timeout, cwd=self.home)
            if not any(line.strip().lower().startswith("type:") for line in listing.splitlines()):
                continue
            argv = [cli, "mcp", "remove", "--scope", str(registration["scope"]), name]
            if act:
                run_host_cli("remove MCP registrations", argv, timeout=self.timeout, cwd=self.home)
            removed.append(" ".join(argv))
        return removed

    def _marked_entries(self, act: bool) -> List[str]:
        removed, warnings, _done = remove_marked_entries(
            load_span_records(self._state()), act=act, lock=self.lock,
            write_bytes=_write_bytes_keep_mode)
        self.warnings = warnings
        if act:
            removed.extend(f"empty folder {folder} (created by setup)"
                           for folder in prune_created_folders(load_created_folders(self._state()), act=True))
        return removed

    def left_for_the_runtime(self) -> List[str]:
        """What an older setup wrote without markers (U10): named, never touched (U4: say what is left)."""
        recorded = tuple(Path(name) for name in load_span_records(self._state()))
        # Only a wiring file that names REACHABLE and that no record covers is
        # left: a Claude Code app holds no wiring (its hooks ship in the plugin),
        # and until 2026-11-18 every such app was reported as left, so a complete
        # uninstall exited 1 (INSTALLER-JOURNEY run 44406868226, J4).
        left = [
            f"REACHABLE wiring in {f} written before markers"
            for w in self.wired_workspaces()
            for f in unrecorded_workspace_wiring(Path(w), recorded)
        ]
        left.extend(
            f"a REACHABLE MCP entry, if any, in {p} written before markers"
            for p in self._rel("mcp_config_files")
            if p.is_file() and p.resolve() not in recorded
        )
        return left


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="uninstall.sh", description=NO_RUNTIME_NOTE)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preview", action="store_true")
    mode.add_argument("--yes", action="store_true")
    export = parser.add_mutually_exclusive_group()
    export.add_argument("--export", metavar="PATH")
    export.add_argument("--no-export", action="store_true")
    parser.add_argument("--workspace")
    args = parser.parse_args(argv)

    layout = json.loads((Path(__file__).resolve().parent / LAYOUT_FILE).read_text(encoding="utf-8"))
    home = Path.home()
    env = dict(os.environ)
    reachable_home = Path(env["REACHABLE_HOME"]).expanduser() if env.get("REACHABLE_HOME") else home / ".reachable"
    run = NoRuntimeUninstall(layout, home=home, reachable_home=reachable_home, env=env)
    print(NO_RUNTIME_NOTE)
    print("Export: nothing to export -- export needs the runtime, which is missing.")
    if args.export:
        print("--export needs the REACHABLE runtime, which is missing. Nothing was removed. "
              "Run again with --no-export.", file=sys.stderr)
        return EXIT_USAGE
    if args.yes and not args.no_export:
        print("Pass --no-export (export needs the runtime, which is missing). Nothing was removed.", file=sys.stderr)
        return EXIT_USAGE
    steps = run.steps()
    try:
        planned = [(name, step(False)) for name, step in steps]
        left = run.left_for_the_runtime()
    except (FullUninstallError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Preview stopped, nothing was removed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return EXIT_NOT_DONE
    for name, items in planned:
        for item in items:
            print(f"  - {'will remove' if args.preview else 'removing'} [{name}] {item}")
    for item in left:
        print(f"  - left, needs the runtime: {item}")
    for warning in run.warnings:
        print(f"  - {warning}")
    if args.preview:
        print("Preview only. Nothing was removed.")
        return EXIT_DONE
    for name, step in steps:
        try:
            step(True)
        except (FullUninstallError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
            print(f"Uninstall stopped at '{name}'; REACHABLE is partly removed: {type(exc).__name__}: {exc}",
                  file=sys.stderr)
            return EXIT_NOT_DONE
    for warning in run.warnings:
        print(warning, file=sys.stderr)
    if left or run.warnings:
        print("REACHABLE is removed from this machine except what is listed as left or warned about above.",
              file=sys.stderr)
        return EXIT_NOT_DONE
    print("REACHABLE is removed from this machine.")
    return EXIT_DONE


if __name__ == "__main__":
    raise SystemExit(main())
