# Security Policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub: open the repository's **Security** tab and
select **Report a vulnerability**. Do not open a public issue.

Include the affected version or commit, the steps to reproduce, and the impact. A deck,
EPUB or dictionary file that shows the problem helps most.

## Scope

Amgi renders content that it does not control: shared Anki decks (HTML and JavaScript),
EPUB files and Yomitan dictionary archives. A file that makes the app read data outside
its own content, open other apps without a tap, or run code outside its web view is in
scope.

Vulnerabilities in the Anki engine belong upstream at
[ankitects/anki](https://github.com/ankitects/anki).

## Supported versions

Only the latest release receives fixes.
