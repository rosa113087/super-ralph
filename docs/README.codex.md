# Super-Ralph for Codex

## Quick Install

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/aezizhu/super-ralph/refs/heads/main/.codex/INSTALL.md
```

## Manual Install

```bash
git clone https://github.com/aezizhu/super-ralph.git ~/.codex/super-ralph
mkdir -p ~/.agents/skills
ln -s ~/.codex/super-ralph/skills ~/.agents/skills/super-ralph
```

Restart Codex.

## How It Works

Codex discovers skills via `~/.agents/skills/`. The symlink points Codex to Super-Ralph's 14 skill directories. Each skill has a `SKILL.md` with YAML frontmatter (`name`, `description`) that Codex uses for auto-discovery.

When you describe a task, Codex automatically matches it to the relevant skill:
- "Build a feature" -> brainstorming -> writing-plans -> test-driven-development
- "Fix this bug" -> systematic-debugging -> test-driven-development
- "Is this done?" -> verification-before-completion

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

```bash
cd ~/.codex/super-ralph && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/super-ralph
rm -rf ~/.codex/super-ralph
```
