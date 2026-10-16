# Forever One Button - notices

Forever One Button is released under the MIT License (see `LICENSE`),
Copyright (c) 2026 DoctorB.

## Code reused from HCOneButton

HCOneButton, Copyright (c) 2026 DoctorB, MIT License,
https://github.com/DoctorB/hc-one-button, commit `e973acb`.

- `Pixel/DiagnosticPixel.lua` is ported from `HCOneButton/UI/DiagnosticPixel.lua`
  (Diagnostic Pixel Protocol v3: colour formula, frame geometry, 60 ms
  acknowledgement edge). No HCOneButton Advisor or decision code is included.
- `Panel/Keys.lua` `Normalize` reuses `HCOB.UI.ActionPanel.NormalizeSlotKey`.
- `Panel/Grid.lua` follows the `ActionButtonUseKeyDown` handling of
  `HCOneButton/UI/CoreHUD.lua`.

## JustAC

JustAC (https://github.com/wealdly/JustAC, GPL-3.0-or-later, Copyright (C)
2024-2026 wealdly) is a separate addon that the user installs. Forever One
Button contains no JustAC code: it only calls JustAC's public
`JustAC-SpellQueue` / `GetCurrentSpellQueue` at run time.
