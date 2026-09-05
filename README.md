# Wiki Community Modules

A collection of globally neutral, decoupled Flutter packages for regional, indigenous, and minority language Wikimedia projects and cultural community applications.

## Included Packages

- [`wiki_course_reader`](packages/wiki_course_reader): Universal course, lesson, and curriculum viewer with rich formatted HTML, pronunciation audio support, and offline caching.
- [`wiki_newsletter_reader`](packages/wiki_newsletter_reader): Universal community bulletin, newsletter, and publication reader with hero cover imagery, pull-to-refresh, and offline reading.

## Design Philosophy

- **Zero Host Coupling**: No dependencies on specific app shells, drawers, or database schemas.
- **Engine vs. Payload**: The packages serve as display and interaction engines; host apps supply their language, domain, and page titles (e.g. `Wikikamus:Sulu` for Nias, or any other wiki page).
- **Global & Script Agnostic**: Designed to support Latin, CJK, Austronesian, and complex scripts across Wikimedia language codes.
