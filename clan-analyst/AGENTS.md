# clan-analyst

BDK project for the Thunderstone review registry. The served prompt is `bot/instructions.md`. The registry itself is `../services/analysis/domain.mjs`.

```bash
npx bdk validate --dir .
npx bdk info --dir . --json
npx bdk call analyze_text --dir . --input '{"text":"TODO"}'
npm run check
```

Run the CLI under Node, never Bun. Do not point `serve` at the parent starter.
