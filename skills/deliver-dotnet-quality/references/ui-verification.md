# UI verification

## Web UI

Use the repository's Playwright binding or equivalent browser runner for critical user journeys. Configure stable `data-testid` selectors, deterministic seed data, fixed time where practical, disabled animations, and captured trace/screenshots on failure.

Separate:

- functional assertions: actions, navigation, displayed state, API outcome;
- visual assertions: a small set of stable screenshots;
- accessibility checks: labels, roles, keyboard flow, and automated scanning;
- human judgment: appearance, copy quality, and unusual interactions.

## Windows desktop UI

For WPF, WinForms, or WinUI, expose stable `AutomationId` values. Use Appium Windows Driver or FlaUI for critical smoke journeys. Treat third-party/custom-drawn controls as an explicit risk; combine automation-tree checks with screenshot evidence and targeted human verification.

## Required evidence

Record the tested application build, environment, viewport/display scaling, scenario, result, screenshot or trace path, and any manual checks. Source-code inspection alone is never UI verification.
