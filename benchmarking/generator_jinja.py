"""
Generator for Jinja2 tempate
"""
import argparse
import json
import os
import sys
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateNotFound

def load_and_validate_json(input_file):
    try:
        path = Path(input_file)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        json_data = json.loads(content.strip())
        return json.dumps(json_data)  #re-serialise for consistency
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {input_file}: {e}")
        sys.exit(1)

def generate_report(input_file, library_paths, output_file=None):
    template_path = Path('template_jinja.jinja2')
    if not template_path.exists():
        print("Error: Template file 'template_jinja.jinja2' not found")
        sys.exit(1)
    
    #load and validate data
    input_data_string = load_and_validate_json(input_file)
    
    #load jQuery
    with open(library_paths['jquery'], 'r', encoding='utf-8') as f:
        jquery_lib = f.read()
    
    #load Chart.js
    with open(library_paths['chartjs'], 'r', encoding='utf-8') as f:
        chart_js_lib = f.read()
    
    #load DataTables JS
    with open(library_paths['datatables_js'], 'r', encoding='utf-8') as f:
        datatables_js_lib = f.read()
    
    #load DataTables CSS
    with open(library_paths['datatables_css'], 'r', encoding='utf-8') as f:
        datatables_css_lib = f.read()
    
    #load Tailwind
    with open(library_paths['tailwind'], 'r', encoding='utf-8') as f:
        tailwind_lib = f.read()
    
    #setup jinja2 environment
    try:
        env = Environment(loader=FileSystemLoader('.'))
        template = env.get_template('template_jinja.jinja2')
        print("Template loaded successfully")
    except TemplateNotFound:
        print("Error: Template 'template_jinja.jinja2' not found")
        sys.exit(1)
    
    #render template
    try:
        html_content = template.render(
            data_string=input_data_string,
            jquery_lib=jquery_lib,
            chart_js_lib=chart_js_lib,
            datatables_js_lib=datatables_js_lib,
            datatables_css_lib=datatables_css_lib,
            tailwind_lib=tailwind_lib
        )
    except Exception as e:
        print(f"Error rendering template: {e}")
        sys.exit(1)
    
    #determine output file
    if output_file is None:
        output_file = 'jinja_report.html'
    
    #write output
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"Generated {output_file}")
    except Exception as e:
        print(f"Error writing output file: {e}")
        sys.exit(1)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generate interactive HTML reports from JSON data",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('data', help='Path to the input JSON data file')
    parser.add_argument('--jquery', help='Path to jQuery library file', required=True)
    parser.add_argument('--chartjs', help='Path to Chart.js library file', required=True) 
    parser.add_argument('--datatables-js', help='Path to DataTables JavaScript library file', required=True)
    parser.add_argument('--datatables-css', help='Path to DataTables CSS library file', required=True)
    parser.add_argument('--tailwind', help='Path to Tailwind CSS library file', required=True)
    parser.add_argument('--output', help='Output HTML file path (default: jinja_report.html)')
    
    return parser.parse_args()


if __name__ == "__main__":
    #parse arguments
    args = parse_arguments()
    
    library_paths = {
        'jquery': args.jquery,
        'chartjs': args.chartjs,
        'datatables_js': args.datatables_js,
        'datatables_css': args.datatables_css,
        'tailwind': args.tailwind
    }
    
    #generate report
    generate_report(args.data, library_paths, args.output)
    print("Done!")