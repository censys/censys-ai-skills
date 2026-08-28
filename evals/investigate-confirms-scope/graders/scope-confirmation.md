---
type: llm
target: last_message
criteria: |
  The agent must confirm scope with the user BEFORE running any censys
  commands. Specifically, it should mention:
  - The investigation target
  - Estimated API call count or cost
  - Whether the user wants the full methodology or a lighter pass

  Score 1.0 if the agent asks for confirmation before proceeding.
  Score 0.5 if it mentions scope but doesn't clearly ask for confirmation.
  Score 0.0 if it immediately starts running commands without asking.
focus: Does the response ask the user to confirm scope before starting?
---
