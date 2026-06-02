import os
import re
import xml.etree.ElementTree as ET

mission_dir = r"c:\Users\kevin\Documents\Arma 3\missions\RACS.porto"
stringtable_path = os.path.join(mission_dir, "stringtable.xml")
output_file = os.path.join(mission_dir, "TEXTE.md")

# 1. Parse stringtable.xml
translations = {}
try:
    tree = ET.parse(stringtable_path)
    root = tree.getroot()
    for key in root.findall('.//Key'):
        key_id = key.get('ID')
        if not key_id: continue
        
        # Try to find French, else English, else Original
        text = ""
        fr = key.find('French')
        en = key.find('English')
        orig = key.find('Original')
        
        if fr is not None and fr.text:
            text = fr.text.strip()
        elif en is not None and en.text:
            text = en.text.strip()
        elif orig is not None and orig.text:
            text = orig.text.strip()
            
        translations[key_id] = text
except Exception as e:
    print(f"Error parsing stringtable.xml: {e}")

# 2. Find usages
file_usages = {} # filename: set of keys
exts = ['.sqf', '.hpp', '.ext', '.sqm']

str_pattern = re.compile(r'(STR_[A-Za-z0-9_]+)')

for root_dir, dirs, files in os.walk(mission_dir):
    if '.git' in root_dir or 'backup' in root_dir:
        continue
    for file in files:
        if any(file.endswith(ext) for ext in exts):
            filepath = os.path.join(root_dir, file)
            rel_path = os.path.relpath(filepath, mission_dir)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = str_pattern.findall(content)
                    if matches:
                        if rel_path not in file_usages:
                            file_usages[rel_path] = set()
                        for m in matches:
                            file_usages[rel_path].add(m)
            except Exception:
                pass

# 3. Generate Markdown
with open(output_file, 'w', encoding='utf-8') as f:
    f.write("# Textes de la mission et leurs emplacements\n\n")
    f.write("Ce fichier répertorie tous les textes traduisibles (`STR_...`) trouvés dans le code et leur valeur correspondante (issue de `stringtable.xml`).\n\n")
    
    for rel_path in sorted(file_usages.keys()):
        keys = sorted(list(file_usages[rel_path]))
        f.write(f"## Fichier : `{rel_path}`\n\n")
        f.write("| Identifiant (Key) | Texte | \n")
        f.write("| --- | --- |\n")
        for k in keys:
            text_val = translations.get(k, "*(Texte non trouvé dans stringtable.xml)*")
            text_val = text_val.replace("\n", "<br>").replace("|", "&#124;")
            f.write(f"| `{k}` | {text_val} |\n")
        f.write("\n")

print("TEXTE.md generated successfully!")
