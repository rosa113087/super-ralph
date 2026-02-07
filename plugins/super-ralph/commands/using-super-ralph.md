---
description: "Start Super-Ralph: autonomous loop + disciplined methodology"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
---

# Super-Ralph

Execute the setup script to initialize the Super-Ralph loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS
```

You are now running **Super-Ralph** — the fusion of Ralph's autonomous loop and the Superpowers engineering methodology.

## How This Works

1. You work on the task using sr- prefixed skills (see below)
2. When you try to exit, the Ralph loop feeds the SAME PROMPT back to you
3. You see your previous work in files and git history
4. You iterate and improve until the task is genuinely complete

## Mandatory Skills (sr- prefix required)

Use these skills for ALL work — no exceptions:

| Situation | Skill to Invoke |
|-----------|----------------|
| New feature or creative work | **sr-brainstorming** |
| Creating implementation plan | **sr-writing-plans** |
| ANY implementation work | **sr-test-driven-development** |
| Bug, error, test failure | **sr-systematic-debugging** |
| Before claiming done | **sr-verification-before-completion** |
| Independent tasks | **sr-subagent-driven-development** |
| Code review | **sr-requesting-code-review** |
| All tasks complete | **sr-finishing-a-development-branch** |

## Enforcement Rules

1. **ANNOUNCE** before using any skill: "I'm using sr-[name] to [purpose]"
2. **NEVER** claim success without running commands and reading output
3. **NEVER** propose fixes without root cause investigation (sr-systematic-debugging)
4. **ONE** fix at a time — test each individually
5. **NO** code formatting degradation — never compress multi-line code to single lines
6. **EVIDENCE** before assertions — every success claim needs command output proof

## Completion Promise

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop. The loop continues until genuine completion.
