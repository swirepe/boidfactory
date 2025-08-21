#!/usr/bin/env python3
import sys
import os
import html
import urllib.parse
import re
import argparse
from pathlib import Path

def setup_arg_parser():
    """Set up the command-line argument parser."""
    parser = argparse.ArgumentParser(
        description="Generates an index.html file with a viewer for all HTML files in a folder.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("root_dir", type=Path, help="The root directory to search for HTML files.")
    parser.add_argument(
        "output_file",
        type=Path,
        nargs="?",
        help="The path for the output HTML file. Defaults to 'index.html' inside the root directory."
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=Path(__file__).parent / "template.html",
        help="Path to the HTML template file."
    )
    return parser

def extract_title(path: Path) -> str:
    """Extracts the <title> from an HTML file, falling back to the filename."""
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")[:4096]
        match = re.search(r"<title[^>]*>(.*?)</title>", content, re.IGNORECASE | re.DOTALL)
        if match:
            title = match.group(1).strip()
            # Return title only if it's not empty
            if title:
                return html.escape(title)
    except (IOError, OSError) as e:
        print(f"Warning: Could not read file {path}: {e}", file=sys.stderr)
    
    # Fallback to the filename if title is missing, empty, or file is unreadable
    return html.escape(path.name)

def main():
    """Main execution function."""
    parser = setup_arg_parser()
    args = parser.parse_args()

    root_dir = args.root_dir.resolve()
    if not root_dir.is_dir():
        print(f"Error: {root_dir} is not a directory.", file=sys.stderr)
        sys.exit(1)

    out_file = args.output_file if args.output_file else root_dir / "index.html"
    out_file = out_file.resolve()
    
    if not args.template.is_file():
        print(f"Error: Template file not found at {args.template}", file=sys.stderr)
        sys.exit(1)

    files_html = list(root_dir.rglob("*.html"))
    files_htm = list(root_dir.rglob("*.htm"))
    all_files = sorted(files_html + files_htm)
    
    files_to_link = [f for f in all_files if f != out_file]

    folder_links = []
    file_links = []

    for f in files_to_link:
        rel_path = f.relative_to(root_dir)
        href = urllib.parse.quote(rel_path.as_posix())

        if f.name.lower() in ('index.html', 'index.htm'):
            folder_name = f.parent.name if f.parent != root_dir else f"{root_dir.name} (Root)"
            data_title = html.escape(folder_name)
            data_filename = html.escape(rel_path.as_posix())
            
            # The initially displayed label is the folder name.
            display_label = data_title

            html_string = (
                f'      <li data-title="{data_title}" data-filename="{data_filename}">'
                f'<a href="{href}" target="_blank" rel="noopener noreferrer">'
                f'📂 <strong>{display_label}</strong></a></li>'
            )
            folder_links.append((display_label.lower(), html_string))
        else:
            page_title = extract_title(f)
            relative_filename = rel_path.as_posix()
            
            data_title = page_title
            data_filename = html.escape(relative_filename)

            # The initially displayed label is the page title.
            display_label = data_title
            
            html_string = (
                f'      <li data-title="{data_title}" data-filename="{data_filename}">'
                f'<a href="{href}" target="viewer">'
                f'<strong>{display_label}</strong></a></li>'
            )
            file_links.append((display_label.lower(), html_string))

    folder_links.sort()
    file_links.sort()

    all_link_items = [item[1] for item in folder_links] + [item[1] for item in file_links]
    links_html = "\n".join(all_link_items)
    
    try:
        template_content = args.template.read_text(encoding="utf-8")
        output_html = template_content.replace("<!-- LINK_LIST_PLACEHOLDER -->", links_html)
        out_file.write_text(output_html, encoding="utf-8")
    except (IOError, OSError) as e:
        print(f"Error writing to output file {out_file}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Successfully generated: {out_file}")
    print(f"Found {len(files_to_link)} HTML file(s) under: {root_dir}")

if __name__ == "__main__":
    main()