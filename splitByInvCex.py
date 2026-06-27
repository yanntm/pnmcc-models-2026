import csv
import xml.etree.ElementTree as ET
import os
import glob
import argparse

# How to use this script :
# Grab the resolution file, e.g. like this : wget https://github.com/yanntm/MCC-analysis/raw/gh-pages/2026/reachability/resolution.csv
# unzip all the models in INPUTS folder, maybe like this : find INPUTS/ -name '*.tgz' -print0 | xargs -0 -I {} tar -xzvf {} -C INPUTS/
# unzip the oracle.tgz file
# invoke this script : pnmcc-models-2026$ python splitByInvCex.py -classification ./resolution.csv -inputs website/INPUTS/ -oracles website/oracle/

# you obtain oracle files and property files suffixed with .INV. .CEX. or .UNK. that partition the properties of the MCC.

def read_classification_csv(csv_path):
    classification = {}
    with open(csv_path, mode='r') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            key = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}-{row['Examination']}-{row['ID']}"
            classification[key] = row['FormulaType']
    return classification

def process_model_directory(model_dir, classification):
    print(f"Processing directory: {model_dir}")
    for file_name in ['ReachabilityCardinality.xml', 'ReachabilityFireability.xml']:
        file_path = os.path.join(model_dir, file_name)
        if os.path.exists(file_path):
            split_xml_file(file_path, classification)

import xml.etree.ElementTree as ET

def split_xml_file(xml_path, classification):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    namespace_uri = root.tag.split('}')[0].strip('{')
    ET.register_namespace('', namespace_uri)  # Register the default namespace to avoid ns0 prefixes

    # Setting up root elements with the correct namespace
    inv_root = ET.Element(f"{{{namespace_uri}}}property-set")
    cex_root = ET.Element(f"{{{namespace_uri}}}property-set")
    unk_root = ET.Element(f"{{{namespace_uri}}}property-set")

    counts = {'INV': 0, 'CEX': 0, 'UNK': 0}

    for prop in root.findall(f'.//{{{namespace_uri}}}property'):
        prop_id = prop.find(f'./{{{namespace_uri}}}id').text
        if prop_id:  # Ensure the property ID is not None
            category = classification.get(prop_id, 'UNK')
            counts[category] += 1

            # Cloning the property to avoid issues related to shared elements
            cloned_prop = ET.fromstring(ET.tostring(prop, encoding='unicode'))

            if category == 'INV':
                inv_root.append(cloned_prop)
            elif category == 'CEX':
                cex_root.append(cloned_prop)
            else:
                unk_root.append(cloned_prop)

    # Writing out the new XML files only if they contain properties
    for cat, new_root in [('INV', inv_root), ('CEX', cex_root), ('UNK', unk_root)]:
        if len(new_root):  # Check if there are elements to write
            new_tree = ET.ElementTree(new_root)
            new_file_path = xml_path.replace('.xml', f'.{cat}.xml')
            try:
                new_tree.write(new_file_path, xml_declaration=True, encoding='utf-8')
            except TypeError as e:
                print(f"Error writing {new_file_path}: {e}")

    print(f"Finished processing {xml_path}: INV={counts['INV']}, CEX={counts['CEX']}, UNK={counts['UNK']}")

def process_oracle_file(oracle_path, classification):
    with open(oracle_path, 'r') as file:
        lines = file.readlines()

    header = lines[0]
    oracle_content = {'INV': [header], 'CEX': [header], 'UNK': [header]}

    for line in lines[1:]:
        parts = line.split()
        if len(parts) > 1:
            formula_id = parts[1]
            category = classification.get(formula_id, 'UNK')
            oracle_content[category].append(line)

    # Write out the new oracle files
    for category, content in oracle_content.items():
        if len(content) > 1:  # There are formulas besides the header
            output_path = f"{oracle_path.replace('.out', f'.{category}.out')}"
            with open(output_path, 'w') as file:
                file.writelines(content)

def main():
    parser = argparse.ArgumentParser(description='Split XML and oracle files based on INV, CEX, and UNK classifications.')
    parser.add_argument('-classification', required=True, help='Path to the classification CSV file.')
    parser.add_argument('-inputs', required=True, help='Path to the input directory containing model subdirectories.')
    parser.add_argument('-oracles', required=True, help='Path to the oracle directory.')
    
    args = parser.parse_args()
    
    # Step 1: Parse the classification
    classification = read_classification_csv(args.classification)

    # Step 2: Walk the inputs folders and create the XML properties split by type
    for model_dir in os.listdir(args.inputs):
        full_path = os.path.join(args.inputs, model_dir)
        if os.path.isdir(full_path):
            process_model_directory(full_path, classification)
    
    # Step 3: Process oracle files
    oracle_files = glob.glob(os.path.join(args.oracles, '*RC.out')) + glob.glob(os.path.join(args.oracles, '*RF.out'))
    for oracle_file in oracle_files:
        process_oracle_file(oracle_file, classification)

if __name__ == "__main__":
    main()

