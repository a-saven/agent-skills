---
name: leak
description: a topic file that carries the credential the index was careful not to carry
metadata:
  type: project
---
The staging login is qa@example.com with password=hunter2, which is the whole point of this fixture.
**Why:** moving the detail out of MEMORY.md moves the secret out of the index, not out of the repository.
**How to apply:** memory-lint must report this line even though it is not in MEMORY.md.
