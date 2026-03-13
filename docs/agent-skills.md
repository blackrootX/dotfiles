# Agent Skills Inventory

Local skill inventory captured from this machine so the same setup can be recreated manually on a new Mac.

## `.agents/skills`

- `browser-use`
  Source: `/Users/blackpig/.agents/skills/browser-use`
  Description: Automates browser interactions for web testing, form filling, screenshots, and data extraction.

- `find-skills`
  Source: `/Users/blackpig/.agents/skills/find-skills`
  Description: Helps discover and install agent skills from the open skills ecosystem.

- `vercel-react-best-practices`
  Source: `/Users/blackpig/.agents/skills/vercel-react-best-practices`
  Description: React and Next.js performance optimization guidance from Vercel Engineering.

- `web-design-guidelines`
  Source: `/Users/blackpig/.agents/skills/web-design-guidelines`
  Description: Reviews UI code against Web Interface Guidelines and accessibility/design best practices.

## `.codex/skills`

- `figma-implement-design`
  Source: `/Users/blackpig/.codex/skills/figma-implement-design`
  Description: Implements Figma nodes into production-ready code using the Figma MCP workflow.

## `.codex/skills/.system`

- `openai-docs`
  Source: `/Users/blackpig/.codex/skills/.system/openai-docs`
  Description: Uses official OpenAI developer docs and docs MCP tooling for current OpenAI guidance.

- `skill-creator`
  Source: `/Users/blackpig/.codex/skills/.system/skill-creator`
  Description: Guidance for creating or updating reusable Codex skills.

- `skill-installer`
  Source: `/Users/blackpig/.codex/skills/.system/skill-installer`
  Description: Installs curated Codex skills or skills from GitHub paths into `$CODEX_HOME/skills`.

## Notes

- This is only an inventory document. It does not install or sync the skills automatically.
- Hidden runtime state, caches, and temporary `npx` downloads are intentionally not tracked here.
- If you want later, this repo can also track a manual reinstall checklist or shell aliases for restoring these skills on a new machine.
