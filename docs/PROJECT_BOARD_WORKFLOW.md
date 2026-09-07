# Project Board Workflow Standard

This document defines the standard Kanban workflow used across all SEOlith GitHub Projects (organization project boards). Every team project board should use this same set of columns, in this order, so that status is predictable across teams and tools (reporting, automation, onboarding).

## Standard columns

| # | Column | Meaning | Exit criteria |
|---|--------|---------|----------------|
| 1 | Backlog | Not yet groomed or prioritized. Default status for new items. | Item is triaged, scoped, and prioritized. |
| 2 | Ready | Groomed, prioritized, and ready to be picked up. | Someone starts active work on it. |
| 3 | Todo | Selected for the current iteration/sprint, not yet started. | Work begins. |
| 4 | In Progress | Actively being worked on. | PR is opened / work is complete and ready for review. |
| 5 | Blocked | Stalled, waiting on something or someone (a dependency, a decision, external input). | Blocker is resolved and work resumes. |
| 6 | Review | Code complete, PR open, awaiting review. | PR is approved and merged. |
| 7 | Testing | Merged and being verified/QA'd (manual or automated). | Verification passes. |
| 8 | Done | Completed. | N/A (terminal state). |

## How items flow

Backlog -> Ready -> Todo -> In Progress -> Review -> Testing -> Done, with Blocked as a side-state that any in-flight item (Todo, In Progress, Review, Testing) can move into and back out of once unblocked.

## Applying this to a project board

Every GitHub Project's `Status` field should contain exactly these eight options, named and ordered as above. To check or fix a project:

1. Open the project, click the `...` menu (top right) -> **Settings**.
2. 2. Under **Fields**, click **Status**.
   3. 3. Confirm all eight options exist, are named exactly as above, and are ordered as above (drag the `::` handle to reorder).
      4. 4. Add any missing option via the **Add option...** box at the bottom, and set a short description on each (visible in group headers and value pickers) matching the "Meaning" column above.
         5. 5. Make sure **Backlog** is marked as the **Default** status (via the option's `...` menu -> **Set as default**) so new items land there automatically.
           
            6. ## Notes
           
            7. - Some boards may also carry a `No Status` bucket (a GitHub default) for items that haven't been triaged into the board yet — that's fine to leave as-is; it's separate from the eight standard columns above.
               - - Project-specific extra fields (Priority, Size, Estimate, Iteration, etc.) are fine to keep in addition to `Status` — this standard only governs the `Status`/Kanban column set.
                 - - If a project's workflow genuinely needs a different shape (e.g. no formal QA stage), raise it with the team before deviating, so reporting and automation that assume this standard aren't broken.
                   - 
