---
description: "Alias for /using-super-ralph — Start Super-Ralph loop"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Super-Ralph Loop (Alias)

This is an alias for `/using-super-ralph`. Execute the setup script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS
```

Please work on the task using the Super-Ralph methodology. Use sr- prefixed skills for all work:
- **sr-brainstorming** before any new feature
- **sr-test-driven-development** for all implementation
- **sr-systematic-debugging** for any bug
- **sr-verification-before-completion** before claiming done

CRITICAL: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE.
