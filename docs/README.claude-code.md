# Super-Ralph for Claude Code

## Quick Install (Plugin)

In Claude Code, run:

```
/plugin add https://github.com/aezizhu/super-ralph
```

Start a new session for skills to take effect.

## How It Works

Super-Ralph includes a `.claude-plugin/marketplace.json` that registers it as a Claude Code plugin marketplace. When you run `/plugin add`, Claude Code:

1. Clones the repository
2. Reads the marketplace manifest
3. Installs the super-ralph plugin with all 14 skills
4. Auto-discovers skills via `SKILL.md` files with YAML frontmatter

When you describe a task, Claude Code automatically matches it to the relevant skill:
- "Build a feature" -> brainstorming -> writing-plans -> test-driven-development
- "Fix this bug" -> systematic-debugging -> test-driven-development
- "Is this done?" -> verification-before-completion

## Alternative: CLAUDE.md Reference

If you prefer not to use the plugin system:

```bash
git clone https://github.com/aezizhu/super-ralph.git ~/.super-ralph
```

Add to your project's `CLAUDE.md`:
```markdown
Read and follow skills from ~/.super-ralph/skills/ directory.
```

## Skills Included

| Skill | Trigger |
|-------|---------|
| brainstorming | New features, creative work, design decisions |
| writing-plans | Approved design ready for implementation breakdown |
| test-driven-development | Any implementation (features, bugs, refactoring) |
| systematic-debugging | Any technical issue (test failures, bugs, errors) |
| verification-before-completion | Before any completion claim or commit |
| subagent-driven-development | Executing plan with independent tasks |
| executing-plans | Batch execution with human checkpoints |
| requesting-code-review | After tasks, before merge |
| receiving-code-review | When receiving review feedback |
| finishing-a-development-branch | All tasks complete, ready to integrate |
| dispatching-parallel-agents | 3+ independent failures |
| using-git-worktrees | Feature isolation |
| using-superpowers | Every conversation (master orchestrator) |
| writing-skills | Creating/editing skills |

## Updating

```
/plugin update super-ralph
```

Or if using the CLAUDE.md method:
```bash
cd ~/.super-ralph && git pull
```

## Uninstalling

Plugin method:
```
/plugin remove super-ralph
```

CLAUDE.md method:
```bash
rm -rf ~/.super-ralph
```
Remove the reference from your `CLAUDE.md`.
