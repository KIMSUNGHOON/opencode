---
name: translation
description: Translation and localization knowledge — preserve rules for code/technical terms, locale-specific glossary usage, and quality checklist. Load this skill when translating documentation or UI text.
references:
  - glossary
---

# Translation & Localization Knowledge Base

Rules for translating technical content while preserving code integrity and technical accuracy.

## Quick Decision Tree: What to Preserve

```
Content type?
├─ Inside backticks (inline code) → NEVER translate
├─ Inside fenced code block → NEVER translate
├─ Product/company name → NEVER translate (keep exact casing)
├─ CLI command or flag → NEVER translate
├─ File path or URL → NEVER translate
├─ Version number → NEVER translate
├─ Environment variable → NEVER translate
├─ Config key/value → NEVER translate
├─ Error message (in code context) → NEVER translate
├─ API name or endpoint → NEVER translate
├─ Acronym (API, CLI, SDK, etc.) → NEVER translate
├─ UI label with locale equivalent → Translate using glossary
├─ Technical concept with standard translation → Translate using glossary
└─ Prose/explanation → Translate naturally
```

## Preservation Rules (MANDATORY)

### Always Preserve Exactly (never modify)

1. **Code blocks** — everything between ``` fences
2. **Inline code** — everything between single backticks
3. **MDX/JSX components** — `<ComponentName>`, imports, props
4. **Markdown structure** — headings, links, images, tables, lists
5. **Front matter** — YAML between `---` delimiters (translate values only if prose)
6. **HTML tags** — preserve tag structure, translate inner text only
7. **Placeholders** — `{variable}`, `{{template}}`, `$VARIABLE`

### Never Translate List

```
Proper nouns:    GitHub, GitLab, Docker, Kubernetes, OpenCode, etc.
Runtime names:   Node.js, Python, Go, Rust, Java, Ruby, PHP, Swift
Tool names:      npm, yarn, pnpm, pip, cargo, maven, gradle
Framework names: React, Vue, Angular, Django, Flask, Express, etc.
CLI commands:    opencode, git, docker, npm, etc.
File names:      package.json, Cargo.toml, go.mod, etc.
Acronyms:        API, CLI, SDK, MCP, LLM, CI, CD, UI, UX, SSO, etc.
```

## Locale-Specific Glossary Usage

### Loading Order
1. Load global Do-Not-Translate terms (always active)
2. Check `.opencode/glossary/<locale>.md` for locale-specific terms
3. If locale alias exists (e.g., `pt-BR` → `br.md`), load that too

### Glossary File Format
```markdown
# Glossary for {locale}

| English Term | Translated Term | Notes |
|---|---|---|
| Repository | リポジトリ | Standard Japanese transliteration |
| Branch | ブランチ | |
| Pull Request | プルリクエスト | Do not abbreviate to PR in body text |
```

### Glossary Priority
```
Locale glossary  > Global glossary  > Natural translation
(most specific)    (do-not-translate)  (fallback)
```

## Translation Quality Checklist

### Before Submitting Translation

- [ ] All code blocks unchanged (diff original vs translated)
- [ ] All inline code unchanged
- [ ] All links still functional (URLs preserved)
- [ ] All images/media references preserved
- [ ] Front matter structure intact
- [ ] MDX components and imports unchanged
- [ ] Markdown formatting preserved (headings, lists, tables)
- [ ] No untranslated prose sections remain
- [ ] Locale glossary terms applied consistently
- [ ] Do-Not-Translate terms preserved exactly
- [ ] Natural reading flow in target language
- [ ] No machine-translation artifacts ("it is a" → natural phrasing)

### Common Mistakes to Avoid

| Mistake | Example | Fix |
|---|---|---|
| Translating code | `npm install` → `npm 설치` | Keep `npm install` |
| Translating brand names | `GitHub` → `깃허브` | Keep `GitHub` |
| Breaking markdown | `[link](url)` → `[링크] (url)` | Keep `[링크](url)` (no space) |
| Translating config keys | `theme: material` → `테마: material` | Keep `theme: material` |
| Inconsistent glossary | "저장소" then "리포지토리" | Pick one, use consistently |
| Literal translation | Word-by-word → unnatural phrasing | Translate meaning, not words |

## Tone and Style by Locale

### General Rules
- Match the formality level of the original
- Technical documentation: prefer formal/professional tone
- Tutorial/guide: conversational but precise
- Error messages: clear and actionable

### Locale-Specific Guidance

| Locale | Honorific Level | Notes |
|--------|----------------|-------|
| ko-KR | 합쇼체/해요체 | Formal for docs, 해요체 for tutorials |
| ja-JP | です/ます | Polite form for all technical writing |
| zh-CN | 您/你 | 您 for formal docs, 你 for tutorials |
| de-DE | Sie/du | Sie for docs, du for community content |
| fr-FR | vous/tu | vous for docs |
| es-ES | usted/tú | usted for docs |
| pt-BR | você | Standard for Brazilian Portuguese |

## Output Format

- Output ONLY the translated content (no commentary, no explanations)
- Preserve the exact file format (markdown, MDX, YAML, etc.)
- If the target locale is missing, ask the user before proceeding
- If uncertain about a term, preserve the English original with a translator note: `<!-- TODO: verify translation of "term" -->`
