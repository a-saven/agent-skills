---
name: dev-server-port
description: shop-web serves on port 3000 in this checkout; the 5173 in package.json is stale
metadata:
  type: project
---
`npm run dev` prints 5173 from the vite default in package.json, but the repo's .env sets PORT=3000 and that wins.
**Why:** every earlier run wasted two tool calls on a refused connection before trying 3000.
**How to apply:** take the URL from `.claude/qa.local.json` first, confirm it with one `curl -sI`, and only then open a browser.
