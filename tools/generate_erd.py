#!/usr/bin/env python3
"""
Generate Mermaid ER diagram from JPA entity classes.

Usage:
  python tools/generate_erd.py
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENTITY_ROOT = PROJECT_ROOT / "src" / "main" / "java"
OUTPUT_FILE = PROJECT_ROOT / "docs" / "db-diagram.mmd"


@dataclass
class Column:
    name: str
    java_type: str
    is_pk: bool = False


@dataclass
class Relation:
    source_entity: str
    source_table: str
    target_entity: str
    relation_type: str
    join_column: str | None = None


@dataclass
class Entity:
    name: str
    table: str
    columns: list[Column] = field(default_factory=list)
    relations: list[Relation] = field(default_factory=list)


def java_to_mermaid_type(java_type: str) -> str:
    t = java_type.replace("java.util.", "")
    mapping = {
        "UUID": "UUID",
        "String": "VARCHAR",
        "Integer": "INT",
        "Long": "BIGINT",
        "Double": "DOUBLE",
        "Float": "FLOAT",
        "Boolean": "BOOLEAN",
        "LocalDate": "DATE",
        "LocalDateTime": "TIMESTAMP",
    }
    return mapping.get(t, t.upper())


def extract_entity(java_file: Path) -> Entity | None:
    text = java_file.read_text(encoding="utf-8")
    if "@Entity" not in text:
        return None

    class_match = re.search(r"\bclass\s+(\w+)", text)
    if not class_match:
        return None
    entity_name = class_match.group(1)

    table_match = re.search(r'@Table\s*\(\s*name\s*=\s*"([^"]+)"', text)
    table_name = table_match.group(1) if table_match else entity_name

    entity = Entity(name=entity_name, table=table_name)

    pending_annotations: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()

        if line.startswith("@"):
            pending_annotations.append(line)
            continue

        field_match = re.match(r"private\s+([A-Za-z0-9_<>\.]+)\s+([A-Za-z0-9_]+)\s*;", line)
        if not field_match:
            if pending_annotations and line:
                # Keep multiline annotation content (e.g. @JoinTable(...)) attached
                # to the next field declaration.
                pending_annotations.append(line)
            elif line.startswith(("public ", "class ", "}", "{")):
                pending_annotations = []
            continue

        field_type = field_match.group(1)
        field_name = field_match.group(2)
        annotation_blob = "\n".join(pending_annotations)

        is_relation = any(
            a in annotation_blob
            for a in ("@ManyToOne", "@OneToMany", "@OneToOne", "@ManyToMany")
        )

        if is_relation:
            rel_type = "unknown"
            if "@ManyToOne" in annotation_blob:
                rel_type = "ManyToOne"
            elif "@OneToMany" in annotation_blob:
                rel_type = "OneToMany"
            elif "@OneToOne" in annotation_blob:
                rel_type = "OneToOne"
            elif "@ManyToMany" in annotation_blob:
                rel_type = "ManyToMany"

            target_type = field_type
            list_match = re.match(r"List<([A-Za-z0-9_]+)>", field_type)
            if list_match:
                target_type = list_match.group(1)

            join_match = re.search(r'@JoinColumn\s*\(\s*name\s*=\s*"([^"]+)"', annotation_blob)
            join_column = join_match.group(1) if join_match else None

            entity.relations.append(
                Relation(
                    source_entity=entity_name,
                    source_table=table_name,
                    target_entity=target_type,
                    relation_type=rel_type,
                    join_column=join_column,
                )
            )
        else:
            is_pk = any(a.startswith("@Id") or a.startswith("@EmbeddedId") for a in pending_annotations)
            entity.columns.append(Column(name=field_name, java_type=field_type, is_pk=is_pk))

        pending_annotations = []

    return entity


def build_mermaid(entities: list[Entity]) -> str:
    lines: list[str] = ["erDiagram"]

    by_name = {e.name: e for e in entities}

    for entity in sorted(entities, key=lambda x: x.table):
        lines.append(f"  {entity.table} {{")
        if not entity.columns:
            lines.append("    UUID id PK")
        for col in entity.columns:
            suffix = " PK" if col.is_pk else ""
            lines.append(f"    {java_to_mermaid_type(col.java_type)} {col.name}{suffix}")
        lines.append("  }")

    seen: set[tuple[str, str, str]] = set()
    for entity in entities:
        for rel in entity.relations:
            target = by_name.get(rel.target_entity)
            if not target:
                continue

            label = rel.join_column or rel.relation_type
            if rel.relation_type == "ManyToOne":
                connector = "}o--||"
            elif rel.relation_type == "OneToMany":
                connector = "||--o{"
            elif rel.relation_type == "OneToOne":
                connector = "||--||"
            else:
                connector = "}o--o{"

            key = (rel.source_table, target.table, rel.relation_type)
            if key in seen:
                continue
            seen.add(key)
            lines.append(f'  {rel.source_table} {connector} {target.table} : "{label}"')

    return "\n".join(lines) + "\n"


def main() -> None:
    java_files = sorted(ENTITY_ROOT.rglob("*Entity.java"))
    entities = [e for f in java_files if (e := extract_entity(f)) is not None]

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(build_mermaid(entities), encoding="utf-8")
    print(f"Generated diagram: {OUTPUT_FILE}")
    print(f"Entities: {len(entities)}")


if __name__ == "__main__":
    main()
