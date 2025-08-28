#!/usr/bin/env python3
import sys
import os
import html
import urllib.parse
import re
import argparse
import base64
import io
import zipfile
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
    
    # SVG icon for download button
    download_icon_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" '
        'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round" class="feather feather-download">'
        '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>'
        '<polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>'
        '</svg>'
    )

    for f in files_to_link:
        rel_path = f.relative_to(root_dir)
        href = urllib.parse.quote(rel_path.as_posix())

        # Create the download link with base64 encoded content
        try:
            file_content = f.read_bytes()
            b64_content = base64.b64encode(file_content).decode('ascii')
            data_uri = f"data:text/html;charset=utf-8;base64,{b64_content}"
            download_filename = html.escape(f.name)
            download_link = (
                f'<a href="{data_uri}" download="{download_filename}" class="download-btn" '
                f'title="Download {download_filename}">{download_icon_svg}</a>'
            )
        except (IOError, OSError) as e:
            print(f"Warning: Could not create download link for {f}: {e}", file=sys.stderr)
            download_link = "" # Don't show button if file can't be read

        if f.name.lower() in ('index.html', 'index.htm'):
            folder_name = f.parent.name if f.parent != root_dir else f"{root_dir.name} (Root)"
            data_title = html.escape(folder_name)
            data_filename = html.escape(rel_path.as_posix())
            display_label = data_title
            
            html_string = (
                f'      <li data-title="{data_title}" data-filename="{data_filename}">'
                f'<a href="{href}" target="_blank" rel="noopener noreferrer">'
                f'📂 <strong>{display_label}</strong></a>{download_link}</li>'
            )
            folder_links.append((display_label.lower(), html_string))
        else:
            page_title = extract_title(f)
            relative_filename = rel_path.as_posix()
            data_title = page_title
            data_filename = html.escape(relative_filename)
            display_label = data_title
            
            html_string = (
                f'      <li data-title="{data_title}" data-filename="{data_filename}">'
                f'<a href="{href}" target="viewer">'
                f'<strong>{display_label}</strong></a>{download_link}</li>'
            )
            file_links.append((display_label.lower(), html_string))

    folder_links.sort()
    file_links.sort()

    # Build a ZIP of all linked files and embed as a data URI for bulk download
    download_all_html = ""
    try:
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            for f in files_to_link:
                try:
                    arcname = f.relative_to(root_dir).as_posix()
                    z.writestr(arcname, f.read_bytes())
                except (IOError, OSError) as e:
                    print(f"Warning: Skipping {f} from ZIP: {e}", file=sys.stderr)
        zip_b64 = base64.b64encode(buf.getvalue()).decode('ascii')
        zip_data_uri = f"data:application/zip;base64,{zip_b64}"
        zip_name = f"{root_dir.name or 'folder'}.zip"
        download_all_html = (
            f'      <li class="download-all">'
            f'<a href="{zip_data_uri}" download="{html.escape(zip_name)}" '
            f'class="download-btn" title="Download entire folder as ZIP">'
            f'📦 <strong>Download All</strong></a></li>'
        )
    except Exception as e:
        print(f"Warning: Could not build ZIP: {e}", file=sys.stderr)

    all_link_items = [download_all_html] + [item[1] for item in folder_links] + [item[1] for item in file_links]
    links_html = "\n".join([s for s in all_link_items if s])
    
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
