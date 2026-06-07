# SEOlith Fleet Theming Standard

All SEOlith-owned web apps should support the same theme family:

- `dark`
- `light`
- `new-york`
- `san-francisco`
- `london`
- `mumbai`
- `tokyo`
- `dubai`
- `sydney`
- `toronto`

## Required Behavior

Each app must:

1. Expose a user-visible theme selector.
2. Persist the selected theme as `seolith.theme`.
3. Set the root attribute:

   ```html
   <html data-seolith-theme="dark">
   ```

4. Use semantic CSS variables instead of hard-coded app chrome colors:

   ```css
   --seolith-bg
   --seolith-fg
   --seolith-surface
   --seolith-surface-2
   --seolith-border
   --seolith-muted
   --seolith-accent
   --seolith-accent-2
   --seolith-danger
   ```

5. Update PWA `theme_color` and browser chrome colors to match the active theme where the framework supports it.
6. Verify WCAG AA contrast for text, buttons, focus states, inputs, tables, badges, charts, and alerts in every theme.

## Rollout Order

1. Portal
2. Apps Showcase
3. Omnifield
4. DebugDojo
5. Hype Buddy
6. TWBB
7. Eventkeep
8. Remaining cataloged apps by fleet priority

## Implementation Notes

Use `seolith-sdk/src/theming` as the canonical source for theme ids, labels, descriptions, runtime helpers, and CSS variables.

Apps may keep their own product personality, but app-specific colors must be layered on top of the semantic tokens instead of replacing the fleet contract.

