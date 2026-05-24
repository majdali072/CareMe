"""
Generate a database schema diagram + tables from the live MongoDB.

Usage:
    cd backend
    python scripts/dump_schema.py [--out <dir>]

Outputs three files in the target directory (default
C:\\Users\\twoqu\\Desktop\\CareMe_Documentation):

  - schema.json           machine-readable per-collection field schema
  - database_diagram.md   Mermaid erDiagram + per-collection tables
  - database_diagram.svg  rendered Mermaid (best effort via npx)

The script samples up to N (default 50) documents per collection and infers
field types from what it actually sees, then merges in the encrypted-fields
map from `api/encryption.py` and a small hand-curated index map so the
diagram shows TTLs and `«encrypted»` markers that pure introspection misses.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from bson import ObjectId
from pymongo import MongoClient

# ---------- Config ----------

DEFAULT_OUT = r"C:\Users\twoqu\Desktop\CareMe_Documentation"
DEFAULT_MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
DEFAULT_DB = os.environ.get("MONGO_DB_NAME", "careme_db")
SAMPLE_LIMIT = 50

# Encrypted-field map mirrors backend/api/encryption.py::ENCRYPTED_FIELDS
ENCRYPTED_FIELDS = {
    "users": ["phone", "dateOfBirth", "address"],
    "medications": ["name", "dosage", "purpose", "sideEffects"],
    "lab_tests": ["name", "doctor"],
}

# Index / TTL info that introspection can't recover. Sourced from
# auth_utils.py, middleware.py, and the OTP / lab-tests endpoints in
# views.py. Keys are field names; values describe the index type.
INDEXES = {
    "refresh_tokens": {
        "token": "unique",
        "user_id": "index",
        "expires_at": "TTL (auto-delete on expiry)",
    },
    "audit_logs": {
        "timestamp": "TTL (~1 year retention)",
        "user_id": "index",
    },
    "otp_codes": {
        "email": "lookup",
        "expires_at": "TTL (auto-delete after 10 min)",
    },
    "fs.chunks": {"files_id": "GridFS internal index"},
}

# Foreign-key style references. Mongo doesn't enforce these; they're how the
# code uses string `user_id` / `fileId` / `files_id` to point at other docs.
RELATIONSHIPS = [
    # (from_collection, from_field, to_collection, to_field, label)
    ("medications", "user_id", "users", "_id", "owns"),
    ("lab_tests", "user_id", "users", "_id", "owns"),
    ("lab_tests", "fileId", "fs.files", "_id", "stores"),
    ("refresh_tokens", "user_id", "users", "_id", "issued for"),
    ("audit_logs", "user_id", "users", "_id", "logged for"),
    ("fs.chunks", "files_id", "fs.files", "_id", "chunk of"),
]


# ---------- Helpers ----------


def _bson_type(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, ObjectId):
        return "ObjectId"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "string"
    if isinstance(value, datetime):
        return "datetime"
    if isinstance(value, bytes):
        return "binary"
    if isinstance(value, list):
        if not value:
            return "array<empty>"
        inner_types = sorted({_bson_type(v) for v in value})
        return f"array<{'|'.join(inner_types)}>"
    if isinstance(value, dict):
        keys = ",".join(value.keys()) if len(value) <= 6 else "..."
        return f"object{{{keys}}}"
    return type(value).__name__


def _looks_like_objectid_string(value: str) -> bool:
    if not isinstance(value, str) or len(value) != 24:
        return False
    try:
        ObjectId(value)
        return True
    except Exception:
        return False


def _sample_collection(coll, limit: int):
    fields = defaultdict(set)            # field -> {type strings}
    nullable = defaultdict(bool)
    objectid_string = defaultdict(bool)  # heuristic: is this string actually a stringified ObjectId?
    seen_docs = 0
    for doc in coll.find().limit(limit):
        seen_docs += 1
        for k, v in doc.items():
            t = _bson_type(v)
            fields[k].add(t)
            if v is None:
                nullable[k] = True
            if isinstance(v, str) and _looks_like_objectid_string(v):
                objectid_string[k] = True
    return {
        "sampled": seen_docs,
        "fields": {k: sorted(v) for k, v in fields.items()},
        "nullable": dict(nullable),
        "objectid_string": dict(objectid_string),
    }


def collect_schema(client: MongoClient, db_name: str):
    db = client[db_name]
    schema = {}
    for name in sorted(db.list_collection_names()):
        coll = db[name]
        info = _sample_collection(coll, SAMPLE_LIMIT)
        info["count"] = coll.estimated_document_count()
        schema[name] = info
    return schema


# ---------- Mermaid rendering ----------


# Mermaid erDiagram syntax forbids dots and a few other characters in entity
# names. We sanitise (`fs.files` -> `fs_files`) and keep a display map so the
# markdown text still uses the real Mongo collection names.
def _mermaid_id(name: str) -> str:
    return name.replace(".", "_")


def _mermaid_field_type(types: list[str]) -> str:
    # Pick a single representative type for the diagram; full type set is in
    # the table below it. Prefer concrete types over "null" / "array<empty>"
    # so an array that's sometimes empty still shows its real element type.
    candidates = [t for t in types if t != "null"]
    if not candidates:
        return "null"
    non_empty = [t for t in candidates if t != "array<empty>"]
    pick = non_empty[0] if non_empty else candidates[0]
    return (
        pick.replace("<", "_of_").replace(">", "")
            .replace("|", "_or_")
            .replace("{", "_").replace("}", "")
            .replace(",", "_").replace(" ", "")
    )


def render_mermaid(schema: dict) -> str:
    lines = ["erDiagram"]

    fk_fields = {
        (frm, field) for (frm, field, *_rest) in RELATIONSHIPS
    }

    for coll_name, info in schema.items():
        ent = _mermaid_id(coll_name)
        lines.append(f"    {ent} {{")
        encrypted = set(ENCRYPTED_FIELDS.get(coll_name, []))
        indexes = INDEXES.get(coll_name, {})
        # Mermaid erDiagram requires at least one attribute per entity. If
        # the collection is empty in this snapshot we fall back to a single
        # `_id` placeholder so the box still renders.
        fields_iter = list(info["fields"].items())
        if not fields_iter:
            fields_iter = [("_id", ["ObjectId"])]
        for field, types in fields_iter:
            t = _mermaid_field_type(types)
            tags = []
            if field == "_id":
                tags.append("PK")
            if (coll_name, field) in fk_fields:
                tags.append("FK")
            if field in encrypted:
                tags.append("encrypted")
            if field in indexes:
                tags.append(indexes[field])
            comment = ""
            if tags:
                # Mermaid puts tags after PK/FK; encryption / TTL go in the
                # quoted comment so they survive escape rules.
                hard = [tg for tg in tags if tg in ("PK", "FK")]
                soft = [tg for tg in tags if tg not in ("PK", "FK")]
                trail = " ".join(hard)
                if soft:
                    comment = ' "' + ", ".join(soft) + '"'
                if trail:
                    lines.append(f"        {t} {field} {trail}{comment}")
                    continue
            lines.append(f"        {t} {field}{comment}")
        lines.append("    }")

    for frm, field, to, to_field, label in RELATIONSHIPS:
        a = _mermaid_id(frm)
        b = _mermaid_id(to)
        lines.append(f'    {b} ||--o{{ {a} : "{label} ({frm}.{field})"')

    return "\n".join(lines)


# ---------- Markdown ----------


def render_markdown(schema: dict, mermaid: str, db_name: str, generated_at: str) -> str:
    out = []
    out.append(f"# CareMe Database Diagram\n")
    out.append(
        f"_Generated from MongoDB `{db_name}` on {generated_at}._\n\n"
        "Each collection below was sampled directly from the running database; "
        "field types reflect what is actually stored. Encryption flags come from "
        "`backend/api/encryption.py`; TTL / index notes come from "
        "`auth_utils.py`, `middleware.py`, and the OTP / lab-tests views.\n"
    )
    out.append("## Entity-Relationship diagram\n")
    out.append("```mermaid")
    out.append(mermaid)
    out.append("```\n")
    out.append("> Open this file in VS Code with a Mermaid preview extension, "
               "or paste the block into https://mermaid.live to view as a graph.\n")

    out.append("## Relationships\n")
    out.append("MongoDB has no foreign keys. The references below are how the "
               "Django backend code links documents:\n")
    out.append("| From | Field | -> | To | Field | Meaning |")
    out.append("|---|---|---|---|---|---|")
    for frm, field, to, to_field, label in RELATIONSHIPS:
        out.append(f"| `{frm}` | `{field}` | -> | `{to}` | `{to_field}` | {label} |")
    out.append("")

    out.append("## Collections\n")
    for coll_name, info in schema.items():
        encrypted = set(ENCRYPTED_FIELDS.get(coll_name, []))
        indexes = INDEXES.get(coll_name, {})
        fk = {
            field for (frm, field, *_rest) in RELATIONSHIPS if frm == coll_name
        }
        out.append(f"### `{coll_name}`")
        out.append(f"_Documents: **{info['count']}**, sampled: {info['sampled']}_\n")
        out.append("| Field | Types | Nullable | Notes |")
        out.append("|---|---|---|---|")
        for field, types in info["fields"].items():
            notes = []
            if field == "_id":
                notes.append("primary key")
            if field in fk:
                target = next(
                    (f"{to}.{tof}"
                     for (frm, fld, to, tof, _) in RELATIONSHIPS
                     if frm == coll_name and fld == field),
                    "",
                )
                notes.append(f"reference -> `{target}`")
            if field in encrypted:
                notes.append("encrypted at rest (Fernet)")
            if field in indexes:
                notes.append(indexes[field])
            if info["objectid_string"].get(field) and "ObjectId" not in types:
                notes.append("string holding a stringified ObjectId")
            null_note = "yes" if info["nullable"].get(field) else "no"
            type_str = ", ".join(f"`{t}`" for t in types)
            note_str = "; ".join(notes) or "-"
            out.append(f"| `{field}` | {type_str} | {null_note} | {note_str} |")
        out.append("")

    out.append("## Generation\n")
    out.append("Re-run any time the schema changes:\n")
    out.append("```bash\ncd backend\npython scripts/dump_schema.py\n```\n")
    return "\n".join(out)


# ---------- SVG render (best effort) ----------


def render_svg(md_path: Path, svg_path: Path) -> tuple[bool, str]:
    """Try to render the Mermaid block to an SVG. Returns (ok, message)."""
    npx = shutil.which("npx") or shutil.which("npx.cmd")
    if not npx:
        return False, "npx not found on PATH"
    try:
        result = subprocess.run(
            [npx, "-y", "@mermaid-js/mermaid-cli", "-i", str(md_path),
             "-o", str(svg_path), "-b", "transparent"],
            capture_output=True, text=True, timeout=180,
        )
        if result.returncode == 0 and svg_path.exists():
            return True, "rendered"
        msg = (result.stderr or result.stdout or "").strip().splitlines()
        tail = msg[-1] if msg else f"exit={result.returncode}"
        return False, f"mermaid-cli failed: {tail}"
    except subprocess.TimeoutExpired:
        return False, "mermaid-cli timed out"
    except Exception as e:
        return False, f"mermaid-cli error: {e}"


# ---------- Main ----------


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", default=DEFAULT_OUT, help="output directory")
    p.add_argument("--mongo-uri", default=DEFAULT_MONGO_URI)
    p.add_argument("--db", default=DEFAULT_DB)
    p.add_argument("--no-svg", action="store_true",
                   help="skip the SVG render even if npx is available")
    args = p.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[+] Connecting to {args.mongo_uri} / {args.db}")
    client = MongoClient(args.mongo_uri, serverSelectionTimeoutMS=5000)
    schema = collect_schema(client, args.db)
    print(f"[+] {len(schema)} collections inspected")

    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    mermaid = render_mermaid(schema)
    md = render_markdown(schema, mermaid, args.db, generated_at)

    json_path = out_dir / "schema.json"
    md_path = out_dir / "database_diagram.md"
    svg_path = out_dir / "database_diagram.svg"

    with json_path.open("w", encoding="utf-8") as f:
        # default=str converts ObjectId/datetime if any slipped through.
        json.dump(schema, f, indent=2, default=str)
    print(f"[+] wrote {json_path}")

    with md_path.open("w", encoding="utf-8") as f:
        f.write(md)
    print(f"[+] wrote {md_path}")

    if args.no_svg:
        print("[-] SVG render skipped (--no-svg)")
    else:
        ok, msg = render_svg(md_path, svg_path)
        if ok:
            print(f"[+] wrote {svg_path}")
        else:
            print(f"[-] SVG not rendered: {msg}")
            print("    The .md still renders in any Mermaid-aware viewer.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
