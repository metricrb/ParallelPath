# Contributing to parallel-path

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

Be respectful, inclusive, and constructive. Treat all contributors with kindness.

## How to contribute

### Reporting bugs

- Check [GitHub Issues](https://github.com/metricrb/parallel-path/issues) to see if the bug is already reported
- Include:
  - Clear description of the problem
  - Steps to reproduce
  - Expected vs actual behavior
  - Roblox Studio version, parallel-path version
  - Minimal code example if possible

### Suggesting features

- Check existing issues and discussions
- Describe the use case clearly
- Explain why it would be useful
- Provide examples if applicable

### Submitting code

1. **Fork the repository** on GitHub
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes**, following the style guide below
4. **Add tests** for new functionality
5. **Update documentation** if you change behavior
6. **Commit with clear messages**: `git commit -am 'Add feature: description'`
7. **Push to your branch**: `git push origin feature/my-feature`
8. **Open a Pull Request** with a clear description

## Development setup

### Prerequisites

- Roblox Studio
- [Aftman](https://github.com/LPGhatguy/aftman) (manages Luau toolchain)
- Git

### Installation

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/parallel-path.git
cd parallel-path

# Install dependencies
aftman install
wally install
```

## Code style

### Luau conventions

- **Strict mode**: All files use `--!strict` at the top
- **Type annotations**: All functions have type signatures
- **Naming**:
  - `PascalCase` for classes/types
  - `camelCase` for functions and variables
  - `_private` prefix for internal/private members
- **Comments**: Only when the "why" is non-obvious
- **Line length**: Keep under 100 characters when practical

### Example function

```luau
--!strict

local function moveTo(agent: Agent, position: Vector3): Promise
    assert(agent, "agent is required")
    assert(position, "position is required")

    return Promise.new(function(resolve, reject)
        -- implementation
    end)
end
```

### Example type definition

```luau
export type Agent = {
    Model: Model,
    Status: AgentStatus,
    MoveTo: (self: Agent, target: Vector3 | BasePart) -> (() -> ()),
    Destroy: (self: Agent) -> (),
}
```

## Documentation

- Keep README.md in sync with actual API
- Update guides when behavior changes
- Add examples for new features
- Write in clear, accessible language
- Test code examples before submitting

### Documentation format

Markdown with GFM extensions. Examples:

```markdown
### agent:MoveTo(target)

Move the agent to a target.

**Parameters:**
- `target: Vector3 | BasePart` — Destination

**Returns:** Cancel function

**Example:**
\`\`\`luau
agent:MoveTo(Vector3.new(0, 5, 0))
\`\`\`
```

## Commit messages

- First line: short summary (under 50 chars)
- Blank line
- Detailed explanation if needed (under 72 chars per line)
- Reference issues: `Fixes #123` or `Related to #456`

Example:

```
Add vehicle steering PID tuning

Expose kp, ki, kd as configurable parameters in agentConfig.
Allows fine-tuning lateral control for different vehicle types.

Fixes #42
```

## PR review process

1. Code review for style, safety, and correctness
2. Tests must pass (CI/CD)
3. Documentation must be updated
4. At least one approval before merge

### What to expect

- Constructive feedback on code
- Suggestions for improvement
- Requests for tests or docs
- Questions about design choices

## Testing guidelines

- Write tests for new functionality
- Test both happy path and edge cases
- Use descriptive test names
- Mock external dependencies where needed
- Aim for high coverage on critical paths

### Test structure

```luau
return function()
    describe("Agent:MoveTo", function()
        it("should move to a position", function()
            -- setup
            local agent = Agent.new(model, config)

            -- execute
            agent:MoveTo(Vector3.new(10, 0, 10))
            task.wait(0.1)

            -- verify
            expect(agent.Status).to.equal("Moving")

            -- cleanup
            agent:Destroy()
        end)
    end)
end
```

## Release process

Releases follow [Semantic Versioning](https://semver.org/):

- **Major** (x.0.0): Breaking API changes
- **Minor** (0.x.0): New features, backward compatible
- **Patch** (0.0.x): Bug fixes

### To release

1. Update `wally.toml` version
2. Update `CHANGELOG.md`
3. Commit and push: `git commit -am 'Release v0.x.x'`
4. Tag: `git tag v0.x.x`
5. Push tags: `git push origin v0.x.x`
6. GitHub Actions builds RBXM and creates release

## Resources

- [Roblox Lua Learning](https://create.roblox.com/docs/scripting/basics/intro-to-scripting)
- [Luau Documentation](https://luau-lang.org/)
- [PathfindingService API](https://create.roblox.com/docs/reference/engine/classes/PathfindingService)
- [Roblox Parallel Luau](https://create.roblox.com/docs/scripting/multithreading/parallel-luau)

## Questions?

- Open a [GitHub Discussion](https://github.com/metricrb/parallel-path/discussions)
- DM on Roblox DevForum
- Check [documentation](https://metricsrb.github.io/parallel-path/)

Thank you for contributing! 🎉
