---
title: "Obsidian Tasks Cheatsheet"
aliases:
  - Obsidian Tasks Cheatsheet
description: >-
  Dense cheatsheet for the Obsidian Tasks plugin: emoji signifiers, date/priority
  fields, status types, query instructions (filters/sort/group/layout), defaults,
  presets, query file defaults, recipes, and Dataview format equivalents.
tags:
  - obsidian
  - plugins
  - task-management
  - productivity
  - workflow
  - markdown
  - dataview
  - query-language
  - cheatsheet
type: cheatsheet
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
language: en
audience: maintainer
platform:
  - Obsidian
sources:
  - "[Tasks User Guide](https://publish.obsidian.md/tasks/)"
  - "[obsidian-tasks repository](https://github.com/obsidian-tasks-group/obsidian-tasks)"
related:
  - "[[Obsidian Tasks Plugin]]"
  - "[[Vault Conventions]]"
  - "[[Home]]"
cssclasses:
  - cheatsheet
  - wide-table
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a teaching guide and cheatsheet for the Obsidian Tasks plugin, with source-code study references"
ai-review: pending
scope: Obsidian Tasks cheatsheet and query reference
keywords:
  - obsidian
  - tasks
  - cheatsheet
  - emoji
  - query
last_reviewed: 2026-10-15
---

# Obsidian Tasks Cheatsheet

> [!summary]
> Quick lookup: writing tasks, emoji signifiers, query instructions, status types, defaults, presets, TQ_* frontmatter, useful recipes. Also maps Emoji → Dataview format.

**Active format:** pick one in Settings → Tasks → Task Formats (Emoji or Dataview). Query/display behavior may vary slightly between views.

## Writing tasks (minimal)

```text
- [ ] do thing ⏳ 2026-10-20 📅 2026-10-22 🔼 🔁 every weekday
- [x] done ✅ 2026-10-15
- [ ] blocked ⛔ abc123
- [ ] blocker 🆔 abc123
```

List styles: `- * + 1. 1)`

## Emoji signifiers

| Field | Emoji | Notes |
|---|---|---|
| Created | `➕` | Auto on create if enabled. |
| Scheduled | `⏳` | Plan/work date. |
| Start | `🛫` | Starts/hides until. |
| Due | `📅` | Strongest urgency weight. |
| Done | `✅` | Auto on completion unless disabled. |
| Cancelled | `❌` | CANCELLED status type. |
| Recurrence | `🔁` | e.g. `every week`, `every day when done`, `every month on the last`. Needs a date. |
| On completion | `🏁` | `keep` (default) or `delete`. Never use `delete` on tasks with nested items. |
| ID | `🆔` | Dependency identifier (letters/digits/_/-). |
| Depends on | `⛔` | Comma-separated IDs. |
| Priority | `🔺 ⏫ 🔼 (none) 🔽 ⏬` | Highest→High→Medium→None→Low→Lowest. |

## Priority & dates quick ref

| Priority | Signifier | Query |
|---|---|---|
| Highest | `🔺` | `priority is highest` |
| High | `⏫` | `priority is high` |
| Medium | `🔼` | `priority is medium` |
| None | (none) | `priority is none` |
| Low | `🔽` | `priority is low` |
| Lowest | `⏬` | `priority is lowest` |

Date filters: `starts/scheduled/due/created/done/cancelled/happens` + `before/after/on`, `in/before/after/in or before/in or after` ranges, `this/next/last week/month/quarter/year`, `YYYY-MM-DD`.

## Status types & core

| Type | Meaning | Typical behavior |
|---|---|---|
| `TODO` | Not started | Matches `not done`. |
| `IN_PROGRESS` | In progress | Matches `not done`. |
| `ON_HOLD` | Held | Matches `not done`. Consider `status.type is not ON_HOLD` in planning queries. |
| `DONE` | Completed | Matches `done`. Adds done date on transition (by default). |
| `CANCELLED` | Cancelled | Matches `done`. Adds cancelled date on transition (by default). |
| `NON_TASK` | Non-task checkbox | Matches `done` (by status-type filter semantics in Tasks). Never gets done date/recurrence. |

Core: `[ ]`→TODO, `[x]`→DONE.

## Tasks query block anatomy

```tasks
# Comment
not done
(due before tomorrow) AND (tags include #work)
sort by due
group by folder
limit 50
explain
```

Assembly order: Global Query (Settings) → Query File Defaults (frontmatter TQ_*) → block content. Later layout overrides earlier. Add `ignore global query` to skip global.

## Filters (common)

| Instruction | Notes |
|---|---|
| `not done` / `done` | Based on status types (TODO/IN_PROGRESS/ON_HOLD vs DONE/CANCELLED/NON_TASK). |
| `starts/scheduled/due/created/done/cancelled before/after/on YYYY-MM-DD` | Absolute dates. |
| `happens before/after/on ...` | Matches any of start/scheduled/due. |
| `no start/scheduled/due/created/done/cancelled/happens date` / `has ... date` | Existence checks. |
| `is recurring` / `is not recurring` | Recurrence rule present/absent. |
| `tags include #x` / `tags do not include #x` / `has tags` / `no tags` | Tag filtering (kebab/case-insensitive in practice). |
| `path/folder/root/filename/heading include ...` | File/heading filters. |
| `description includes ...` / `description regex matches /.../` | Text search. |
| `priority is (highest\|high\|medium\|none\|low\|lowest)` | Priority filter. |
| `is blocked` / `is not blocked` / `is blocking` / `is not blocking` | Dependency posture. |
| `has id` / `no id` / `id includes ...` | Task identity. |
| `exclude sub-items` | Top-level tasks only. |
| `( ... ) AND ( ... ) OR ( ... ) NOT ( ... )` | Boolean; `AND/OR/NOT` capitalized. |

## Sorting & Grouping

| Sort | Notes | Group | Notes |
|---|---|---|---|
| `sort by status.type` | Default first. | `group by status.type` | IN_PROGRESS/TODO/DONE/CANCELLED/NON_TASK. |
| `sort by urgency` | Default second. | `group by status.name` | Human-readable names. |
| `sort by due` | Default third. | `group by due/scheduled/start/created/done/cancelled` | By date buckets. |
| `sort by priority` | Default fourth. | `group by priority` | By priority level. |
| `sort by path` | Default fifth. | `group by path/root/folder/filename/heading` | File structure. |
| `sort by scheduled/start/created/done/cancelled` | Date sorts. | `group by tags` | Split by tags. |
| `sort by description` | Lexicographic. | `group by recurrence` | Recurrence rule text. |
| `sort by tag` / `sort by tag 2` | First/second tag. | `group by backlink` | Source note. |
| `sort by lineNumber` | File order. | `group by id` | Identity groups. |
| `sort by random` | Random order. | — | — |

**Defaults (auto-appended):** `sort by status.type`, `sort by urgency`, `sort by due`, `sort by priority`, `sort by path`. Add at least one `sort by` to override.

## Layout, views, limiting

| Instruction | Notes |
|---|---|
| `show tree` / `hide tree` | Show nested tasks/list items in results. |
| `short mode` / `full mode` | Condense/expand date/recurrence display. |
| `view list` | Default list view. |
| `view columns by <group-field>` | Column view (drag-drop supported for some fields). |
| `show urgency` / `hide urgency` | Display urgency score. |
| `hide due/scheduled/start/created/done/cancelled date` | Hide date fields. |
| `hide priority` / `hide tags` / `hide recurrence rule` / `hide on completion` / `hide id` / `hide depends on` | Hide task elements. |
| `hide toolbar` / `hide edit button` / `hide postpone button` / `hide backlink` / `hide nested backlink` / `hide task count` | Hide query UI elements. |
| `show group count` | Show count per leaf group. |
| `limit N` | Max total tasks. |
| `limit groups N` | Max per group. |
| `explain` | Show assembled query + expanded dates/regex. |
| `ignore global query` | Skip Settings global query. |
| `preset <name>` or `{{preset.<name>}}` | Insert preset instructions. |
| `# comment` / `{{! inline comment }}` | Comments. |

## Defaults, presets, Query File Defaults (TQ_*)

**Default presets (Settings → Presets):**
- `this_file` → `path includes {{query.file.path}}`
- `this_folder` → `folder includes {{query.file.folder}}`
- `this_folder_only` → `filter by function task.file.folder === query.file.folder`
- `this_root` → `root includes {{query.file.root}}`
- `hide_date_fields` → hides all date fields
- `hide_non_date_fields` → hides id/depends on/recurrence/on completion/priority
- `hide_query_elements` → hides toolbar/postpone/edit/backlinks/task count
- `hide_everything` → combines the above

**Query File Defaults (frontmatter in query file):** insert before all blocks in that file.

Common TQ_*:
- `TQ_extra_instructions: |- ...` (multi-line)
- `TQ_short_mode: true/false`
- `TQ_show_tree: true/false`
- `TQ_explain: true/false`
- `TQ_show_urgency: true/false`
- `TQ_show_task_count: true/false`
- `TQ_show_toolbar: true/false`
- `TQ_show_edit_button: true/false`
- `TQ_show_postpone_button: true/false`
- `TQ_show_backlink: true/false`
- `TQ_show_nested_backlink: true/false`
- `TQ_show_id`, `TQ_show_depends_on`, `TQ_show_priority`, `TQ_show_tags`, `TQ_show_recurrence_rule`, `TQ_show_on_completion`, `TQ_show_due_date`, `TQ_show_scheduled_date`, `TQ_show_start_date`, `TQ_show_created_date`, `TQ_show_done_date`, `TQ_show_cancelled_date`

## Quick recipes

| Goal | Query |
|---|---|
| Due today (open) | `not done` + `due today` |
| Due this week (open, not overdue) | `not done` + `due after yesterday` + `due before in two weeks` |
| Inbox work due soon | `(tags include #inbox OR path includes Inbox)` + `not done` + `due before in 14 days` |
| Overdue (open) | `not done` + `due before today` |
| Scheduled this quarter, has tags | `scheduled this quarter` + `has tags` |
| Done this month | `done this month` |
| Top-level only (no subtasks) | `exclude sub-items` + `not done` |
| Actionable (not blocked) | `not done` + `is not blocked` |
| Blockers (blocking others) | `is blocking` + `not done` |
| Stuck (blocked) | `is blocked` + `not done` |
| Show only tasks starting now or earlier | `starts before tomorrow` (includes no start date by default). |
| Use filename as default date context | Combine with `preset this_file` + happens filters; see docs on "Use filename as default date". |

## Emoji → Dataview format equivalents

| Field | Emoji | Dataview inline field |
|---|---|---|
| Created | `➕ YYYY-MM-DD` | `[created:: YYYY-MM-DD]` |
| Scheduled | `⏳ YYYY-MM-DD` | `[scheduled:: YYYY-MM-DD]` |
| Start | `🛫 YYYY-MM-DD` | `[start:: YYYY-MM-DD]` |
| Due | `📅 YYYY-MM-DD` | `[due:: YYYY-MM-DD]` |
| Done | `✅ YYYY-MM-DD` | `[completion:: YYYY-MM-DD]` |
| Cancelled | `❌ YYYY-MM-DD` | `[cancelled:: YYYY-MM-DD]` |
| Recurrence | `🔁 every ...` | `[repeat:: every ...]` |
| On completion | `🏁 keep\|delete` | `[onCompletion:: keep\|delete]` |
| ID | `🆔 abc123` | `[id:: abc123]` |
| Depends on | `⛔ a,b` | `[dependsOn:: a,b]` |
| Priority | `🔺/⏫/🔼/🔽/⏬` | `[priority:: highest/high/medium/low/lowest]` |

## Gotchas (cheatsheet)

- **Single-line only.** Multiline checklist items not supported.
- **Parse backwards.** Metadata must come before tags/block links at end.
- **Global filter tag.** Don't search for the same tag as global filter.
- **`🏁 delete` breaks nesting.** Never on parent with nested items.
- **JS disabled by default (8.0.0+).** Enable "Enable custom searches" for `filter/sort/group by function`.
- **Restart after updates/settings.** Fixes many odd behaviors.
- **One format at a time.** Emoji vs Dataview; switching affects read/write.
- **Postpone only in query results.** Not in source/edit modal.
- **Recurring tasks need a date.** And `id`/`dependsOn` removed on next recurrence.

## Sources
- [Tasks User Guide](https://publish.obsidian.md/tasks/) — documentation, authoritative
- [obsidian-tasks repository](https://github.com/obsidian-tasks-group/obsidian-tasks) — source-code, authoritative

## Related

- [[Obsidian Tasks Plugin]]
- [[Vault Conventions]]