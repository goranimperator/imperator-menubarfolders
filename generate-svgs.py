#!/usr/bin/env python3
"""Generate SVG files from LucideIcons.swift icon data into Resources/icons/"""

import re
import os

SOURCE = "Sources/MenuBarFolders/Services/LucideIcons.swift"
OUTPUT = "Resources/icons"

os.makedirs(OUTPUT, exist_ok=True)

with open(SOURCE) as f:
    source = f.read()

# Find all icon entries: "name": [#"<elem/>"#, ...]
# Parse the icon dictionary block
icon_pattern = re.compile(r'"([a-z0-9-]+)"\s*:\s*\[([^\]]+)\]')
elem_pattern = re.compile(r'#"(.+?)"#')

count = 0
for match in icon_pattern.finditer(source):
    name = match.group(1)
    raw = match.group(2)
    elements = elem_pattern.findall(raw)
    if not elements:
        continue

    indent = "  "
    elems_str = f"\n{indent}".join(elements)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  {elems_str}
</svg>
'''

    with open(os.path.join(OUTPUT, f"{name}.svg"), "w") as f:
        f.write(svg)
    count += 1

print(f"Generated {count} SVG files in {OUTPUT}/")
