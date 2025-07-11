"""
Mutator of SCIFR template
"""
import argparse
import orjson

def mutate_report(data_json, template, startIdx, endIdx):
   #load json data
   with open(data_json, 'r', encoding='utf-8') as f:
       json_data = orjson.loads(f.read().strip())
   
   #load template
   with open(template, 'r', encoding='utf-8') as f:
       template_content = f.read()
   
   #find the section to replace using string operations
   marker = "JSON.parse('"
   end_marker = "')"
   
   #first find startIdx to narrow down the search
   approx_pos = template_content.find(startIdx)
   if approx_pos == -1:
       raise ValueError(f"Error: Could not find startIdx '{startIdx}' in template file.")
   
   #search backwards from startIdx to find JSON.parse('
   search_start = max(0, approx_pos - 100)
   start_pos = template_content.find(marker, search_start)
   if start_pos == -1:
       raise ValueError("Error: Could not find JSON.parse(' before startIdx in template file.")
   
   #find endIdx position
   endIdx_pos = template_content.find(endIdx, start_pos)
   if endIdx_pos == -1:
       raise ValueError(f"Error: Could not find endIdx '{endIdx}' after JSON.parse in template file.")
   
   #find the ending ') after endIdx
   start_content_pos = start_pos + len(marker)
   end_pos = template_content.find(end_marker, endIdx_pos + len(endIdx))
   if end_pos == -1:
       raise ValueError("Error: Could not find closing ') after endIdx in template file.")
   
   #create the JSON string using orjson for better performance
   json_bytes = orjson.dumps(json_data, option=orjson.OPT_NON_STR_KEYS)
   new_json_str = json_bytes.decode('utf-8')
   new_json_str = new_json_str.replace('\\', '\\\\')  #double escape backslashes first
   new_json_str = new_json_str.replace("'", "\\'")    #then escape single quotes
   
   #assemble the final content using slicing
   prefix = template_content[:start_content_pos]
   suffix = template_content[end_pos:]
   updated_content = prefix + new_json_str + suffix
   
   #write output
   output_file = 'scifr_report.html'
   with open(output_file, 'w', encoding='utf-8', buffering=1024*1024) as f:
       f.write(updated_content)

def parse_arguments():
   parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
   parser.add_argument('--data_json', help='Path to the SCIFR input JSON data file', required=True)
   parser.add_argument('--template', help='Path to SCIFR template file', required=True)
   parser.add_argument('--startIdx', help='Start index identifier', required=True)
   parser.add_argument('--endIdx', help='End index identifier', required=True)
   return parser.parse_args()

if __name__ == "__main__":
   args = parse_arguments()
   mutate_report(args.data_json, args.template, args.startIdx, args.endIdx)
   print("Done!")