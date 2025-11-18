#!/usr/bin/env python3
"""Remove empty DartDoc lines (///) from Dart files."""

import os
import re

def remove_empty_dartdoc(directory):
    """Remove lines that are just /// with optional whitespace."""
    pattern = re.compile(r'^\s*///\s*$\n', re.MULTILINE)
    files_modified = []
    total_lines_removed = 0

    for root, dirs, files in os.walk(directory):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.')]

        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Count matches before removal
                matches = len(pattern.findall(content))

                if matches > 0:
                    new_content = pattern.sub('', content)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)

                    files_modified.append((filepath, matches))
                    total_lines_removed += matches

    return files_modified, total_lines_removed

if __name__ == '__main__':
    lib_dir = 'lib'
    files_modified, total_removed = remove_empty_dartdoc(lib_dir)

    print(f"Removed {total_removed} empty /// lines from {len(files_modified)} files:")
    for filepath, count in sorted(files_modified, key=lambda x: -x[1])[:20]:
        print(f"  {filepath}: {count} lines")

    if len(files_modified) > 20:
        print(f"  ... and {len(files_modified) - 20} more files")
