import re

def fix_remaining():
    with open('lib/services/supabase_service.dart', 'r') as f:
        content = f.read()

    # Find ANY method starting with `_getMock` and ensure it returns empty immediately.
    # regex: `(List|Map|String|int|double|bool|[\w<>]+)\s+(_getMock[A-Za-z0-9_]+\s*\([^)]*\)\s*)\{`
    
    def replacer(match):
        return_type = match.group(1)
        method_signature = match.group(2)
        
        if 'List' in return_type:
            return f'{return_type} {method_signature} {{ return [];'
        elif 'Map' in return_type:
            return f'{return_type} {method_signature} {{ return {{}};'
        elif 'int' in return_type or 'double' in return_type:
            return f'{return_type} {method_signature} {{ return 0;'
        else:
            return f'{return_type} {method_signature} {{ return null;'

    content = re.sub(r'([A-Za-z0-9_<>]+)\s+(_getMock[A-Za-z0-9_]+\s*\([^)]*\)\s*)\{', replacer, content)

    # Clean up double braces again just in case
    content = re.sub(r'\{\s*return\s+\[\];\s*if\s*\(_mock', r'{ return []; if (_mock', content)
    content = re.sub(r'\{\s*return\s+\[\];\s*\{\s*return\s+\[\];', r'{ return [];', content)
    content = re.sub(r'\{\s*return\s+null;\s*\{\s*return\s+null;', r'{ return null;', content)

    with open('lib/services/supabase_service.dart', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    fix_remaining()
