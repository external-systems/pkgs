"""Inline external reveal.js Markdown into the deck's HTML.

For every .html file under the given directory, each
`<section data-markdown="x.md" ...></section>` becomes
`<section data-markdown ...><textarea data-template>…x.md…</textarea></section>`,
and the inlined .md files are deleted. The built deck then needs no
fetch() (works from file://), and MkDocs never sees a stray .md file when
the deck is copied into the docs site.
"""

import html
import pathlib
import re
import sys

SECTION = re.compile(
    r'<section(?P<pre>[^>]*?)\sdata-markdown="(?P<src>[^"]+)"(?P<post>[^>]*)>\s*</section>'
)

root = pathlib.Path(sys.argv[1])
inlined = set()
for page in root.rglob("*.html"):
    text = page.read_text(encoding="utf-8")

    def inline(match):
        src = (page.parent / match["src"]).resolve()
        inlined.add(src)
        body = html.escape(src.read_text(encoding="utf-8"), quote=False)
        return (
            f'<section{match["pre"]} data-markdown{match["post"]}>'
            f"<textarea data-template>\n{body}</textarea></section>"
        )

    page.write_text(SECTION.sub(inline, text), encoding="utf-8")

for src in inlined:
    src.unlink()
