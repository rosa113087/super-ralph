# Super-Ralph for OpenCode

## Quick Install

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/aezizhu/super-ralph/refs/heads/main/.opencode/INSTALL.md
```

## Manual Install

```bash
git clone https://github.com/aezizhu/super-ralph.git ~/.config/opencode/super-ralph
mkdir -p ~/.config/opencode/skills
ln -s ~/.config/opencode/super-ralph/skills ~/.config/opencode/skills/super-ralph
```

Restart OpenCode.

## How It Works

OpenCode discovers skills via `~/.config/opencode/skills/`. The symlink points OpenCode to Super-Ralph's 14 skill directories. Each skill has a `SKILL.md` with YAML frontmatter that OpenCode uses for auto-discovery.

Use OpenCode's native `skill` tool to load specific skills:
```
use skill tool to load super-ralph/brainstorming
use skill tool to load super-ralph/test-driven-development
```

## Tool Mapping

When skills reference Claude Code tools, the OpenCode equivalents are:
- `TodoWrite` -> `update_plan`
- `Task` with subagents -> `@mention` syntax
- `Skill` tool -> OpenCode's native `skill` tool
- File operations -> your native tools

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
cd ~/.config/opencode/super-ralph && git pull
```

## Uninstalling

```bash
rm ~/.config/opencode/skills/super-ralph
rm -rf ~/.config/opencode/super-ralph
```
