import os
import xml.etree.ElementTree as ET

def merge_xml_files():
    # Determine the directory of the script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    tasks_dir = os.path.join(script_dir, "tasks")
    output_file = os.path.join(script_dir, "stringtable.xml")
    
    if not os.path.exists(tasks_dir):
        print(f"Error: tasks folder not found at '{tasks_dir}'")
        return
        
    print(f"Scanning '{tasks_dir}' recursively for XML files...")
    xml_files = []
    for root_dir, _, files in os.walk(tasks_dir):
        for file in files:
            if file.endswith(".xml"):
                xml_files.append(os.path.join(root_dir, file))
    
    if not xml_files:
        print("No XML files found in tasks folder.")
        return
        
    rel_paths = [os.path.relpath(f, tasks_dir) for f in xml_files]
    print(f"Found files: {', '.join(rel_paths)}")
    
    # Predefined order of containers for the output
    container_order = ["Briefing", "Tasks", "Dialogues", "Debriefing"]
    containers_dict = {} # name -> list of keys (Element)
    seen_keys = {} # key_id -> relative_filepath
    
    for filepath in xml_files:
        rel_filepath = os.path.relpath(filepath, tasks_dir)
        try:
            tree = ET.parse(filepath)
            root = tree.getroot()
            
            # Find all Container elements (can be direct children or under Project/Package)
            containers = root.findall(".//Container")
            for container in containers:
                container_name = container.attrib.get("name")
                if not container_name:
                    continue
                
                if container_name not in containers_dict:
                    containers_dict[container_name] = []
                
                # Extract all Key children
                keys = container.findall("Key")
                for key in keys:
                    key_id = key.attrib.get("ID")
                    if not key_id:
                        continue
                    
                    if key_id in seen_keys:
                        print(f"WARNING: Duplicate Key ID '{key_id}' found in '{rel_filepath}' (already defined in '{seen_keys[key_id]}'). Skipping.")
                        continue
                    
                    seen_keys[key_id] = rel_filepath
                    containers_dict[container_name].append(key)
                    
            print(f"Successfully processed: {rel_filepath}")
        except Exception as e:
            print(f"Error reading {rel_filepath}: {e}")
            
    # Build final XML structure
    root_merged = ET.Element("Project", {"name": "UnstablePorto"})
    package_merged = ET.SubElement(root_merged, "Package", {"name": "Missions"})
    
    # Add containers in predefined order first
    for name in container_order:
        if name in containers_dict and containers_dict[name]:
            container_el = ET.SubElement(package_merged, "Container", {"name": name})
            for key in containers_dict[name]:
                container_el.append(key)
                
    # Add any other containers found that are not in the predefined list
    for name, keys in containers_dict.items():
        if name not in container_order and keys:
            container_el = ET.SubElement(package_merged, "Container", {"name": name})
            for key in keys:
                container_el.append(key)
                
    # Indentation helper for clean formatting (compatible with older Python versions)
    def indent(elem, level=0):
        i = "\n" + level * "  "
        if len(elem):
            if not elem.text or not elem.text.strip():
                elem.text = i + "  "
            if not elem.tail or not elem.tail.strip():
                elem.tail = i
            for child in elem:
                indent(child, level + 1)
            if not child.tail or not child.tail.strip():
                child.tail = i
        else:
            if level and (not elem.tail or not elem.tail.strip()):
                elem.tail = i

    indent(root_merged)
    
    # Write to stringtable.xml
    merged_tree = ET.ElementTree(root_merged)
    try:
        merged_tree.write(output_file, encoding="utf-8", xml_declaration=True)
        print(f"\nSuccess: Merged XML written to '{output_file}'")
    except Exception as e:
        print(f"Error writing output file: {e}")

if __name__ == "__main__":
    merge_xml_files()
