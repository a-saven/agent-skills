---
name: checkout-flow
description: the stable locators on shop-web checkout, and the one that keeps moving
metadata:
  type: project
---
Drive checkout by role and name: `role=button name="Place order"` has survived three redesigns.
**Why:** `data-testid` on the same button was renamed twice (`checkout-submit`, then `place-order-btn`), so a testid locator flakes between releases.
**How to apply:** snapshot the page, pick the accessible name, and only fall back to a testid when no accessible name exists.
