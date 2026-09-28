import re
import ast

def main():
    # Read the translated UPDATE statements
    with open('actualizar_ejercicios_espanol.sql', 'r', encoding='utf-8') as f:
        update_lines = f.readlines()
        
    translations = {}
    
    update_pattern = re.compile(
        r"UPDATE public\.ejercicios SET name = '(.*?)', categoria = '(.*?)', description = '(.*?)' WHERE id = '(.*?)';"
    )
    
    for line in update_lines:
        match = update_pattern.search(line)
        if match:
            name, categoria, description, ex_id = match.groups()
            translations[ex_id] = {
                'name': name,
                'categoria': categoria,
                'description': description
            }
            
    # Read the original INSERT statements
    with open('ejercicios_rows.sql', 'r', encoding='utf-8') as f:
        insert_text = f.read()
        
    values_text = insert_text.split("VALUES ")[1].strip()
    if values_text.endswith(";"):
        values_text = values_text[:-1]
        
    # Split by "), ("
    if values_text.startswith("("):
        values_text = values_text[1:]
    if values_text.endswith(")"):
        values_text = values_text[:-1]
        
    # More robust split using regex to find everything inside (...)
    # Since there are no nested parenthesis in our data (usually)
    # Wait, some descriptions have parenthesis!
    # Let's just use regex to extract the 6 single-quoted strings for each tuple
    # A tuple has exactly 6 string values.
    
    # regex to find tuples
    tuple_pattern = re.compile(r"\((.*?)\)(?:,\s*\(|\Z)", re.DOTALL)
    
    raw_tuples = []
    # Hacky way to split:
    # replace '), (' with ')|||(' and then split
    safe_text = values_text.replace("), (", ")|||(")
    split_tuples = safe_text.split(")|||(")
    
    new_inserts = []
    
    for t in split_tuples:
        # Extract string values: they are wrapped in '...' and separated by ,
        # Some values might be NULL but here they are all strings.
        # Find all strings inside '...'
        matches = re.findall(r"'((?:[^']|'')*)'", t)
        
        if len(matches) == 6:
            ex_id = matches[0]
            created_at = matches[1]
            name = matches[2]
            description = matches[3]
            image_url = matches[4]
            categoria = matches[5]
            
            # Apply translation
            if ex_id in translations:
                trans = translations[ex_id]
                name = trans['name']
                categoria = trans['categoria']
                description = trans['description']
            else:
                # Need to un-escape original SQL quotes if they were escaped
                name = name.replace("''", "'")
                description = description.replace("''", "'")
                categoria = categoria.replace("''", "'")
                
            # Escape for SQL output
            name_esc = name.replace("'", "''")
            desc_esc = description.replace("'", "''")
            cat_esc = categoria.replace("'", "''")
            
            new_tuple = f"('{ex_id}', '{created_at}', '{name_esc}', '{desc_esc}', '{image_url}', '{cat_esc}')"
            new_inserts.append(new_tuple)
        else:
            print("Failed to parse tuple:", t)
            
    with open('insert_ejercicios_espanol.sql', 'w', encoding='utf-8') as f:
        f.write("-- SCRIPT SQL DE INSERCIÓN MASIVA DE EJERCICIOS TRADUCIDOS AL ESPAÑOL\n")
        f.write("-- Nota: Ejecuta este archivo en el SQL Editor de Supabase después de eliminar los ejercicios existentes.\n\n")
        
        chunk_size = 50
        for i in range(0, len(new_inserts), chunk_size):
            chunk = new_inserts[i:i+chunk_size]
            f.write('INSERT INTO "public"."ejercicios" ("id", "created_at", "name", "description", "image_url", "categoria") VALUES\n')
            f.write(",\n".join(chunk))
            f.write(";\n\n")
            
    print(f"Generated {len(new_inserts)} inserts.")

if __name__ == '__main__':
    main()
