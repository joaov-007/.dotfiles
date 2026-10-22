---
title: "Obsidian Tasks Plugin"
aliases:
  - Obsidian Tasks
  - Tasks plugin
  - Tasks
description: >-
  Teaching guide to the Obsidian Tasks community plugin: checklist syntax, emoji
  signifiers, task formats, the tasks query language, statuses, recurrence and
  dependencies — plus a map of the plugin's TypeScript source for further study.
tags:
  - obsidian
  - plugins
  - task-management
  - productivity
  - workflow
  - markdown
  - dataview
  - query-language
  - javascript
type: guide
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
  - "[Tasks releases / changelog](https://github.com/obsidian-tasks-group/obsidian-tasks/releases)"
related:
  - "[[Obsidian Tasks Cheatsheet]]"
  - "[[Vault Conventions]]"
  - "[[Home]]"
  - "[[Note Template]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a teaching guide and cheatsheet for the Obsidian Tasks plugin, with source-code study references"
ai-review: pending
scope: Obsidian Tasks plugin syntax and query language
keywords:
  - obsidian
  - tasks
  - plugin
  - query language
  - emoji
last_reviewed: 2026-10-15
---

# Obsidian Tasks Plugin

> [!summary]
> Obsidian Tasks turns plain checklist items into trackable tasks. It reads tasks from notes, queries them with `tasks` code blocks, supports emoji metadata (dates, priorities, recurrence, dependencies, statuses), and can auto-update source lines (e.g. add done dates, spawn recurring tasks). This guide covers writing tasks, querying, common workflows, gotchas, and a source-map for studying the codebase.

**Version note:** Verified against Tasks 8.x (8.0.0, May 2026). JavaScript in queries is disabled by default since 8.0.0; some details change between releases.

## Context

Obsidian [checklist items](https://help.obsidian.md/Editing+and+formatting/Basic+formatting+syntax#Checklist+lists) look like `- [ ] do thing`. The Tasks plugin:

- Tracks single-line tasks across your vault (Tasks only supports single-line checklist items).
- Lets you enrich tasks with emoji signifiers (e.g. `📅 2026-10-15`, `🔼`, `🔁 every week`) or Dataview-style inline fields `[due:: 2026-10-15]` in one supported format at a time.
- Provides `tasks` query blocks to filter/sort/group/limit/display results.
- Adds commands (Create or edit task, Toggle Done, Change status to…), a context menu, auto-suggest, and the Postpone button in query results.
- Can optionally track created/done/cancelled dates and create next instances for recurring tasks.

Caveat: This vault does not currently have the Tasks community plugin installed; treat this guide as a teaching/spec reference and verify behavior in your own vault.

## Install and first run

1. Community plugins → Browse → search "Tasks" → Install → Enable.
2. **Restart Obsidian** if behavior seems odd after settings changes (a few settings require reload).
3. Settings → Tasks: set a [Global Filter](https://publish.obsidian.md/tasks/Getting+Started/Global+Filter) if you only want specific checkboxes tracked (optional). If empty, all checklist items are treated as tasks.
4. Optional: Remap "Toggle checkbox status" to "Tasks: Toggle Done" for consistent done-date/recurrence handling.
5. If you use JS-powered custom filters/sorts/groups, explicitly enable **Enable custom searches** (Settings → Tasks → Searches) because JavaScript is disabled by default in 8.0.0.

## Writing tasks

### Basic syntax

Any of these list styles are allowed:

```text
- [ ] hyphen
* [ ] asterisk
+ [ ] plus
1. [ ] numbered dot
1) [ ] numbered parenthesis
```

Example:

```text
- [ ] Read vault conventions ⏳ 2026-10-20 🔼
- [ ] Weekly review 🔁 every Sunday 📅 2026-10-25
- [x] Ship thing ✅ 2026-10-14
```

### Task formats: Emoji vs Dataview

Tasks supports **one format at a time** (Settings → Tasks → Task Formats). Reading/writing in the active format; reading-mode/query display often still shows emojis regardless in current versions.

- **Tasks Emoji Format (default):** use emoji signifiers inline (e.g. `📅 2026-10-16`, `⏫`, `🔁 every day when done`, `🏁 delete`, `🆔 abcdef`, `⛔ abcdef,ghijkl`).
- **Dataview Format:** use bracketed inline fields: `[due:: 2026-10-16]`, `[priority:: high]`, `[repeat:: every day when done]`, `[onCompletion:: delete]`, `[id:: abcdef]`, `[dependsOn:: abcdef,ghijkl]`. Works best with bracket auto-pairing and requires typing `[]`/`()`. There are subtle differences vs Dataview's parser; read the format docs carefully.

### Core signifiers (Emoji)

| Field | Emoji | Example | Notes |
|---|---|---|---|
| Created | `➕` | `➕ 2026-10-15` | Auto-added if "Set created date on every added task" enabled (modal/new task). |
| Scheduled | `⏳` | `⏳ 2026-10-20` | "Plan to work on" date. |
| Start | `🛫` | `🛫 2026-10-18` | Hide until this date; filters often include tasks without start date. |
| Due | `📅` | `📅 2026-10-22` | Strongest influence on urgency. |
| Done | `✅` | `✅ 2026-10-15` | Auto-added on completion unless disabled. |
| Cancelled | `❌` | `❌ 2026-10-15` | For cancelled tasks (CANCELLED status type). |
| Recurrence | `🔁` | `🔁 every weekday when done` | Requires at least one date (due/scheduled/start) as reference. `when done` bases next on completion date. |
| On completion | `🏁` | `🏁 delete` | Action on done: `keep` (default) or `delete` (removes completed instance; be careful with nested items). |
| ID | `🆔` | `🆔 abc123` | Uniquely identifies a task for dependencies (letters/digits/_/-). |
| Depends on | `⛔` | `⛔ abc123,def456` | Comma-separated IDs; this task is blocked until those are DONE/CANCELLED/NON_TASK. |
| Priority | `🔺⏫🔼🔽⏬` | `🔺` | Highest→High→Medium→(none)→Low→Lowest. Tasks with no priority sit between Low and Medium in effect. |

> [!warning] Parsing order matters
> Tasks reads backwards from end of line for metadata. Tags and block links must come after metadata; anything else breaks parsing. This is the most common source of "fields not recognized". Use the "Create or edit task" modal to debug, or search for unread emojis.

## Queries (`tasks` code blocks)

Add a code block with `tasks` to list/filter tasks in that note (Reading/Live Preview).

Minimal examples:

```tasks
not done
due today
```

```tasks
done this week
group by folder
sort by due
```

### Pipeline (how a query is assembled)

For any `tasks` block in a file:
1. **Global Query** (Settings) — prepended unless `ignore global query` appears in block.
2. **Query File Defaults** (file frontmatter properties like `TQ_extra_instructions`, `TQ_short_mode`, `TQ_show_tree`, etc.) — prepended next.
3. **Query Source** (lines in the code block) — appended.

Later layout instructions override earlier. Use `explain` to see the assembled query and expanded dates.

### Core instruction categories

- **Filters:** `not done`, `done`, `starts before tomorrow`, `scheduled before tomorrow`, `due before tomorrow`, `happens before tomorrow`, `no due date`, `has due date`, `is recurring`, `is not recurring`, `tags include #foo`, `path includes ...`, `folder includes ...`, `root includes ...`, `filename includes ...`, `heading includes ...`, `description includes ...`, `priority is high`, `is blocked`, `is not blocked`, `is blocking`, `is not blocking`, `has id`, `no id`, `exclude sub-items`, regex filters (`regex matches`/`does not match`), etc. Combine with `AND`/`OR`/`NOT` and parentheses.
- **Sorting:** `sort by status.type`, `sort by urgency`, `sort by due`, `sort by scheduled`, `sort by start`, `sort by created`, `sort by done`, `sort by cancelled`, `sort by priority`, `sort by path`, `sort by filename`, `sort by heading`, `sort by description`, `sort by tag`, `sort by lineNumber`, `sort by random`. Defaults (auto-appended): `sort by status.type`, `sort by urgency`, `sort by due`, `sort by priority`, `sort by path`. To override defaults, add at least one `sort by` in query.
- **Grouping:** `group by status.type`, `group by status.name`, `group by due`, `group by scheduled`, `group by start`, `group by created`, `group by done`, `group by cancelled`, `group by priority`, `group by path`, `group by root`, `group by folder`, `group by filename`, `group by heading`, `group by tags`, `group by backlink`, `group by recurrence`, etc. Multiple groups nest.
- **Layout & display:** hide/show task elements (`hide due date`, `hide tags`, `hide priority`, `hide recurrence rule`, `hide on completion`, `hide id`, `hide depends on`, etc.) and query elements (`hide toolbar`, `hide edit button`, `hide postpone button`, `hide backlink`, `hide nested backlink`, `hide task count`, `show urgency`, `show tree`, `show group count`). Modes: `short mode`, `full mode`. Views: `view list` (default), `view columns by ...`.
- **Limiting & others:** `limit N`, `limit groups N`, `explain` (show assembled query), `ignore global query`, `preset <name>` or `{{preset.name}}` for reusing instructions, comments `# ...` and inline `{{! ... }}`.
- **Query file defaults (frontmatter):** `TQ_extra_instructions` (multi-line), `TQ_short_mode`, `TQ_show_tree`, and boolean toggles like `TQ_show_due_date`, `TQ_show_tags`, `TQ_show_urgency`, `TQ_show_toolbar`, `TQ_show_edit_button`, `TQ_show_postpone_button`, `TQ_show_backlink`, `TQ_show_task_count`, `TQ_explain`, etc. Also `TQ_show_id`, `TQ_show_depends_on`, `TQ_show_recurrence_rule`, `TQ_show_on_completion`, `TQ_show_created_date`, `TQ_show_start_date`, `TQ_show_scheduled_date`, `TQ_show_done_date`, `TQ_show_cancelled_date`, `TQ_show_priority`. These are inserted before the block.
- **Presets:** reusable named instruction sets defined in Settings → Tasks → Presets. Use `preset my_name` or embed `{{preset.my_name}}` inside boolean combinations/partial expressions. Defaults include `this_file`, `this_folder`, `this_folder_only`, `this_root`, `hide_date_fields`, `hide_non_date_fields`, `hide_query_elements`, `hide_everything`.

## Statuses, toggling, and posture

- **Status types (6):** `TODO`, `IN_PROGRESS`, `ON_HOLD`, `DONE`, `CANCELLED`, `NON_TASK`. These determine behavior (e.g. when done dates added, whether recurrence creates next task, whether task is considered blocked).
- **Core statuses:** `[ ]` (TODO) and `[x]` (DONE) work out of the box. Custom statuses let you define symbols, next status, and type.
- **Toggling:** left-click checkbox in Live Preview/Reading; `Tasks: Toggle Done` command (assign hotkey); "Change task status" context menu (right-click/long-press on checkbox in Reading/Query results) to pick any registered status; Create/edit modal can change status.
- **Postpone (`⏩`):** in query results only (Live Preview/Reading), click advances date to tomorrow or day after current (earliest), right-click opens menu to pick date or remove date. Configurable which date field is edited (Due→Scheduled→Start default).
- **Create or edit task modal:** central UI to set description, dates, priority, recurrence, on-completion, status, and dependencies (searches for other tasks by description). Also supports access keys (configurable).

## Dependencies and recurrence details

- **Dependencies:** an `id` on a task and `dependsOn` (comma-separated ids) on another create a finish-to-start (FS) link. A task is **blocked** if it is not done and depends on any not-done tasks. A task is **blocking** if not done and some other not-done task depends on it directly. Use `is blocked`, `is not blocked`, `is blocking`, `is not blocking`, `has id`, `no id` filters.
- **Recurrence:** `when done` uses completion date as reference; without it uses original reference date. Monthly/yearly edge cases exist (e.g. "last day", "31st" skips months). Recurring tasks must have at least one date. Completing recurring tasks with custom statuses has specific rules (see docs). When completed, next recurrence gets `id`/`dependsOn` removed by design.
- **On completion:** `🏁 delete` deletes the just-completed instance (never put on a task that has nested items; it can break indentation).

## Gotchas and limitations

- **Single-line only.** Tasks ignores content after the first line in a multi-line checklist item.
- **Parsing order.** Read backwards from end; metadata before tags/blocklinks? Tags/blocklinks must be after metadata. Anything else stops parsing.
- **No Canvas, no code blocks.** Tasks does not read tasks inside Obsidian Canvas cards or inside code blocks (use callouts instead).
- **Comments.** `<!-- ... -->` and `%% ... %%` comments hide tasks from Tasks (Obsidian doesn't read them).
- **Footnotes.** Only inline footnotes work in rendered task lines; regular footnotes not supported in query results.
- **Date format fixed.** `YYYY-MM-DD` only; no times in task date fields (reminder plugin can add times separately).
- **Numbered lists.** Read fine; in query results displayed as bullets.
- **Callouts/Blockquotes.** Read fine, but clicking checkbox in Live Preview inside callouts may behave oddly in some versions; prefer command or Reading view.
- **Global filter tag.** If global filter is a tag, do not use that tag in searches (it’s stripped from task lines).
- **"Delete on completion" breaks nesting.** Never use `🏁 delete` on a parent task with nested subtasks/list items.
- **JS disabled by default (8.0.0+).** Custom `filter/sort/group by function` require enabling "Enable custom searches". Placeholders/expressions may still be affected; treat untrusted vault content as untrusted.
- **Restart after updates/settings changes.** Try restart if Tasks behaves unexpectedly.
- **Task format is global and single-format.** If you pick Dataview format, Emoji signifiers are no longer read/written until you switch back. Reading/query display may not fully respect chosen format in all views.

## Verification checklist

1. Create a test note and add `- [ ] test task 📅 2026-10-16` (Emoji format). In Live Preview/Reading, the date should be recognized.
2. Add a `tasks` block: `not done` + `due today`/`due before tomorrow`. Run `explain` to see expanded dates.
3. Toggle done (`Tasks: Toggle Done`) — confirm done date added (`✅ YYYY-MM-DD`).
4. Create a recurring task: `- [ ] sweep 🔁 every day 📅 2026-10-16` — toggle done; confirm next instance appears with updated date.
5. Try Postpone (`⏩`) on a dated task in a query result; check date shifts to tomorrow or context menu.
6. If using custom functions, enable "Enable custom searches" and test a small `filter by function task.due?.isToday()`.

## Studying the source

Base: [https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/)

Suggested reading order: `main.ts` → `src/Task/Task.ts` + `src/TaskSerializer/*` → `src/Obsidian/FileParser.ts` + `src/Obsidian/Cache.ts` → `src/Query/Query.ts` + `src/Query/Filter/Field.ts` → a concrete `*Field.ts` (e.g. `DueDateField.ts`) → `src/Query/Sort/Sorter.ts`, `src/Query/Group/Grouper.ts` → `src/Renderer/QueryRenderer.ts`, `src/Renderer/TaskLineRenderer.ts` → `src/Scripting/*`, `src/Config/*`, `src/Api/*`.

### Key source files by area

| Area | Path | What to read |
|---|---|---|
| Entry | [`src/main.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/main.ts) | Plugin lifecycle, registration of commands, events, settings tab, API. |
| Task model | [`src/Task/Task.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/Task.ts), [`src/Task/TaskRegularExpressions.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/TaskRegularExpressions.ts) | How a task line becomes a `Task` object; regex for parsing. |
| Priority/Urgency/Recurrence/Deps | [`src/Task/Priority.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/Priority.ts), [`src/Task/Urgency.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/Urgency.ts), [`src/Task/Recurrence.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/Recurrence.ts), [`src/Task/TaskDependency.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Task/TaskDependency.ts) | Scoring, recurrence rules/next instance, dependency graph concepts. |
| Task serialization (formats) | [`src/TaskSerializer/DefaultTaskSerializer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/TaskSerializer/DefaultTaskSerializer.ts), [`src/TaskSerializer/DataviewTaskSerializer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/TaskSerializer/DataviewTaskSerializer.ts), [`src/TaskSerializer/index.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/TaskSerializer/index.ts) | Emoji vs Dataview format read/write; format selection behavior. |
| Vault scanning | [`src/Obsidian/FileParser.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Obsidian/FileParser.ts), [`src/Obsidian/Cache.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Obsidian/Cache.ts), [`src/Query/Scanner.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Scanner.ts) | Extracting tasks from markdown, caching, scanning query results context. |
| Query engine | [`src/Query/Query.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Query.ts), [`src/Query/FilterParser.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/FilterParser.ts), [`src/Query/Statement.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/QueryComponentOrError.ts), [`src/IQuery.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/IQuery.ts) | Query assembly (global+defaults+source), statement parsing, instruction dispatch. |
| Filter fields | [`src/Query/Filter/Field.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/Field.ts), [`src/Query/Filter/DateField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/DateField.ts), [`src/Query/Filter/DueDateField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/DueDateField.ts), [`src/Query/Filter/HappensDateField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/HappensDateField.ts), [`src/Query/Filter/PriorityField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/PriorityField.ts), [`src/Query/Filter/TagsField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/TagsField.ts), [`src/Query/Filter/StatusField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/StatusField.ts), [`src/Query/Filter/StatusTypeField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/StatusTypeField.ts), [`src/Query/Filter/BlockingField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/BlockingField.ts), [`src/Query/Filter/IdField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/IdField.ts), [`src/Query/Filter/DependsOnField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/DependsOnField.ts) | Concrete filters; how each instruction is implemented. |
| Boolean logic | [`src/Query/Filter/BooleanField.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/BooleanField.ts), [`src/Query/Filter/BooleanPreprocessor.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/BooleanPreprocessor.ts), [`src/Query/Filter/BooleanDelimiters.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Filter/BooleanDelimiters.ts) | `AND`/`OR`/`NOT`, parentheses, tokenization/preprocessing. |
| Sort/Group | [`src/Query/Sort/Sort.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Sort/Sort.ts), [`src/Query/Sort/Sorter.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Sort/Sorter.ts), [`src/Query/Group/Grouper.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Group/Grouper.ts), [`src/Query/Group/TaskGroups.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Group/TaskGroups.ts), [`src/Query/Group/TaskGroupingTree.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Group/TaskGroupingTree.ts), [`src/Query/Group/GroupDisplayHeading.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Group/GroupDisplayHeading.ts) | Default sort chain, grouping tree, headings. |
| Explain/Presets/Query File Defaults | [`src/Query/Explain/Explainer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Explain/Explainer.ts), [`src/Query/Presets/Presets.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Presets/Presets.ts), [`src/Query/QueryFileDefaults.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/QueryFileDefaults.ts) | How `explain` expands instructions, preset resolution, frontmatter defaults. |
| Renderers/Layout | [`src/Renderer/QueryRenderer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Renderer/QueryRenderer.ts), [`src/Renderer/TaskLineRenderer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Renderer/TaskLineRenderer.ts), [`src/Renderer/MarkdownQueryResultsRenderer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Renderer/MarkdownQueryResultsRenderer.ts), [`src/Renderer/HtmlQueryResultsRenderer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Renderer/HtmlQueryResultsRenderer.ts), [`src/Renderer/HtmlColumnQueryResultsRenderer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Renderer/HtmlColumnQueryResultsRenderer.ts), [`src/Layout/QueryLayout.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Layout/QueryLayout.ts), [`src/Layout/TaskLayout.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Layout/TaskLayout.ts) | Rendering tasks/queries, columns view, show/hide/tree. |
| Scripting/JS & placeholders | [`src/Scripting/ExpandPlaceholders.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/ExpandPlaceholders.ts), [`src/Scripting/Expression.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/Expression.ts), [`src/Scripting/TaskExpression.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/TaskExpression.ts), [`src/Scripting/QueryContext.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/QueryContext.ts), [`src/Scripting/TasksFile.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/TasksFile.ts), [`src/Scripting/KnownPlaceholderResolver.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/KnownPlaceholderResolver.ts), [`src/Scripting/JsInTasksQueriesDisabledError.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Scripting/JsInTasksQueriesDisabledError.ts) | Placeholders, `filter/sort/group by function`, JS-gating (8.0.0+). |
| Commands, toggling, modal | [`src/Commands/ToggleDone.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Commands/ToggleDone.ts), [`src/Commands/ChangeStatusCommands.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Commands/ChangeStatusCommands.ts), [`src/Commands/CreateOrEdit.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Commands/CreateOrEdit.ts), [`src/Commands/CreateOrEditTaskParser.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Commands/CreateOrEditTaskParser.ts), [`src/Obsidian/TaskModal.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Obsidian/TaskModal.ts), [`src/ui/EditTask.svelte`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/ui/EditTask.svelte) | Core editing/toggling UX; modal logic. |
| Dates/Postponer | [`src/DateTime/TasksDate.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/DateTime/TasksDate.ts), [`src/DateTime/DateParser.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/DateTime/DateParser.ts), [`src/DateTime/Postponer.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/DateTime/Postponer.ts), [`src/ui/Menus/PostponeMenu.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/ui/Menus/PostponeMenu.ts) | Date parsing/representation and postpone behavior. |
| Settings/Presets/Statuses | [`src/Config/Settings.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Config/Settings.ts), [`src/Config/SettingsTab.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Config/SettingsTab.ts), [`src/Query/Presets/PresetsSettingsService.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Query/Presets/PresetsSettingsService.ts), [`src/Statuses/StatusRegistry.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Statuses/StatusRegistry.ts), [`src/Statuses/Status.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Statuses/Status.ts) | Settings model/UI, presets, status registry/types. |
| API | [`src/Api/TasksApiV1.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Api/TasksApiV1.ts), [`src/Api/createTaskLineModal.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Api/createTaskLineModal.ts), [`src/Api/editTaskLineModal.ts`](https://github.com/obsidian-tasks-group/obsidian-tasks/blob/main/src/Api/editTaskLineModal.ts) | Public API surface (used by QuickAdd and other integrations). |

## Related

- [[Obsidian Tasks Cheatsheet]]
- [[Vault Conventions]]
- [[Home]]
- [[Note Template]]

## Sources

- [Tasks User Guide](https://publish.obsidian.md/tasks/) — canonical docs (Getting Started, Queries, Editing, Advanced, Reference).
- [obsidian-tasks GitHub](https://github.com/obsidian-tasks-group/obsidian-tasks) — source, issues, discussions, releases.
- [Tasks Releases](https://github.com/obsidian-tasks-group/obsidian-tasks/releases) — changelog and breaking changes.