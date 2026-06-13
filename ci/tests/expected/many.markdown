<!-- deadwood-summary -->
🪵 **Deadwood** — 2 new dead declaration(s) introduced by this change:

- `Sources/App/Checkout.swift:42` function `unusedHelper()`
- `Sources/App/Cart.swift:17` var `staleFlag`

Remove them, or wire them up. If Periphery is wrong (protocol witness, @objc, reflection, public API), add a `// periphery:ignore` comment or a retain rule.
