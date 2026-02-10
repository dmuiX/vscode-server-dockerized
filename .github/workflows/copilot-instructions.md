AGENTS.md/copilot-instructions.md

This repository contains plain HTML, CSS, and JavaScript.
Follow the conventions below strictly when contributing.

⸻

Commit messages

Use Conventional Commits:

type(scope optional): short imperative
# AGENTS.md

This repository contains plain HTML, CSS, and JavaScript.  
Follow the conventions below strictly when contributing.

---

## Commit messages

Use **Conventional Commits**:

```
type(scope optional): short imperative
```

### Allowed types
- feat
- fix
- docs
- chore
- refactor
- test
- perf
- ci
- build

### Examples
- feat: add language toggle for landing page
- fix: correct layout shift on mobile
- docs: explain access layer concept
- refactor: simplify language switch logic

---

## General principles

- Keep everything simple, readable, and explicit
- Prefer clarity over cleverness
- Avoid frameworks unless explicitly required
- No build step by default (plain HTML / CSS / JS)
- All logic must be understandable by reading the file top-to-bottom

---

## JavaScript conventions

### Structure
- One responsibility per file
- Keep scripts small and focused
- No global state unless unavoidable
- Group code logically:
  - CONFIG
  - HELPERS
  - STATE
  - DOM SELECTORS
  - EVENT HANDLERS
  - INIT / BOOTSTRAP

### Style
- Use `const` by default, `let` only when reassignment is required
- Never use `var`
- Prefer arrow functions for inline callbacks
- Use named functions for reusable logic
- Use strict equality `===` / `!==`

### Errors & guards
- Guard early (check required DOM elements before use)
- Fail fast with clear console messages
- Never silently ignore errors

### Strings & interpolation
- Use template literals for interpolation:
  ```js
  `Hello ${name}`
  ```
- Use single quotes only for true literals
- Never build strings via concatenation when interpolation is clearer

### DOM interaction
- Cache DOM queries once
- Never query the same selector repeatedly
- Prefer `data-*` attributes over hard-coded selectors
- Keep DOM writes minimal

### Example
```js
// CONFIG
const DEFAULT_LANG = 'en';

// HELPERS
const setText = (el, text) => {
  if (!el) {
    console.error('Missing element for text update');
    return;
  }
  el.textContent = text;
};

// INIT
document.addEventListener('DOMContentLoaded', () => {
  console.info('App initialized');
});
```

---

## HTML conventions

### Structure
- Use semantic HTML (`header`, `main`, `section`, `nav`, `footer`)
- Keep nesting shallow and readable
- One logical section per `<section>`

### Attributes
- Prefer `data-*` attributes for JS hooks
- Avoid styling hooks in JS (no `.js-*` classes)
- Use `aria-*` attributes where appropriate

### Accessibility
- All interactive elements must be keyboard accessible
- Images require `alt` attributes
- Buttons must be `<button>` elements, not clickable `<div>`

### Language & content
- Content should be readable without JavaScript
- JavaScript may enhance, not replace core content
- Avoid inline scripts

---

## CSS conventions

### Structure
- One global stylesheet unless explicitly split
- Order sections consistently:
  - VARIABLES
  - RESET / BASE
  - LAYOUT
  - COMPONENTS
  - UTILITIES

### Style rules
- Use CSS variables for colors, spacing, and typography
- Avoid inline styles
- Avoid deep selectors
- Prefer class selectors over element selectors
- No `!important` unless absolutely necessary

### Naming
- Use clear, descriptive class names
- Avoid abbreviations unless obvious
- Keep naming consistent across components

### Example
```css
:root {
  --color-bg: #0b0d10;
  --color-accent: #3ddc84;
}

.card {
  border-radius: 16px;
  padding: 18px;
}
```

---

## Language / i18n handling

- Do not duplicate entire HTML pages unnecessarily
- Keep language logic explicit and deterministic
- Default language must be defined in code
- Language switching must not rely on browser heuristics

---

## Logging & debugging

- Use `console.info`, `console.warn`, `console.error`
- Log meaningful messages only
- Remove debug logs before merging unless explicitly useful

---

## What NOT to do

- No hidden magic
- No implicit globals
- No framework-specific patterns
- No premature abstractions
- No copy-paste without understanding

---

## Guiding rule

Make the code readable for someone seeing it for the first time.  
If it needs explanation, simplify it.

Allowed types
	•	feat
	•	fix
	•	docs
	•	chore
	•	refactor
	•	test
	•	perf
	•	ci
	•	build

Examples
	•	feat: add language toggle for landing page
	•	fix: correct layout shift on mobile
	•	docs: explain access layer concept
	•	refactor: simplify language switch logic

⸻

General principles
	•	Keep everything simple, readable, and explicit
	•	Prefer clarity over cleverness
	•	Avoid frameworks unless explicitly required
	•	No build step by default (plain HTML/CSS/JS)
	•	All logic must be understandable by reading the file top-to-bottom

⸻

JavaScript conventions

Structure
	•	One responsibility per file
	•	Keep scripts small and focused
	•	No global state unless unavoidable
	•	Group code logically:
	•	CONFIG
	•	HELPERS
	•	STATE
	•	DOM SELECTORS
	•	EVENT HANDLERS
	•	INIT / BOOTSTRAP

Style
	•	Use const by default, let only when reassignment is required
	•	Never use var
	•	Prefer arrow functions for inline callbacks
	•	Use named functions for reusable logic
	•	Use strict equality === / !==

Errors & guards
	•	Guard early (check required DOM elements before use)
	•	Fail fast with clear console messages
	•	Never silently ignore errors

Strings & interpolation
	•	Use template literals for interpolation:
Hello ${name}
	•	Use single quotes only for true literals
	•	Never build strings via concatenation when interpolation is clearer

DOM interaction
	•	Cache DOM queries once
	•	Never query the same selector repeatedly
	•	Prefer data-* attributes over hard-coded selectors
	•	Keep DOM writes minimal

Example

// CONFIG
const DEFAULT_LANG = 'en';

// HELPERS
const setText = (el, text) => {
  if (!el) {
    console.error('Missing element for text update');
    return;
  }
  el.textContent = text;
};

// INIT
document.addEventListener('DOMContentLoaded', () => {
  console.info('App initialized');
});


⸻

HTML conventions

Structure
	•	Use semantic HTML (header, main, section, nav, footer)
	•	Keep nesting shallow and readable
	•	One logical section per <section>

Attributes
	•	Prefer data-* attributes for JS hooks
	•	Avoid styling hooks in JS (no .js-* classes)
	•	Use aria-* attributes where appropriate

Accessibility
	•	All interactive elements must be keyboard accessible
	•	Images require alt attributes
	•	Buttons must be <button> elements, not clickable <div>

Language & content
	•	Content should be readable without JavaScript
	•	JavaScript may enhance, not replace core content
	•	Avoid inline scripts

⸻

CSS conventions

Structure
	•	One global stylesheet unless explicitly split
	•	Order sections consistently:
	•	VARIABLES
	•	RESET / BASE
	•	LAYOUT
	•	COMPONENTS
	•	UTILITIES

Style rules
	•	Use CSS variables for colors, spacing, and typography
	•	Avoid inline styles
	•	Avoid deep selectors
	•	Prefer class selectors over element selectors
	•	No !important unless absolutely necessary

Naming
	•	Use clear, descriptive class names
	•	Avoid abbreviations unless obvious
	•	Keep naming consistent across components

Example

:root {
  --color-bg: #0b0d10;
  --color-accent: #3ddc84;
}

.card {
  border-radius: 16px;
  padding: 18px;
}


⸻

Language / i18n handling
	•	Do not duplicate entire HTML pages unnecessarily
	•	Keep language logic explicit and deterministic
	•	Default language must be defined in code
	•	Language switching must not rely on browser heuristics

⸻

Logging & debugging
	•	Use console.info, console.warn, console.error
	•	Log meaningful messages only
	•	Remove debug logs before merging unless explicitly useful

⸻

What NOT to do
	•	No hidden magic
	•	No implicit globals
	•	No framework-specific patterns
	•	No premature abstractions
	•	No copy-paste without understanding

⸻

Guiding rule

Make the code readable for someone seeing it for the first time.
If it needs explanation, simplify it.

⸻
