import re

def fix_clean():
    with open('lib/services/supabase_service.dart', 'r') as f:
        content = f.read()

    # Fix the double brace issue
    content = re.sub(r'(\w+)\s+(_getMock[A-Za-z0-9_]+\([^{]*\)\s*{)\s*{\s*return\s+\[\];', r'\1 \2 return [];', content)
    content = re.sub(r'(\w+)\s+(_getMock[A-Za-z0-9_]+\([^{]*\)\s*{)\s*{\s*return\s+null;', r'\1 \2 return null;', content)
    content = re.sub(r'(\w+)\s+(_getMock[A-Za-z0-9_]+\([^{]*\)\s*{)\s*{\s*return\s+0;', r'\1 \2 return 0;', content)
    content = re.sub(r'(\w+)\s+(_getMock[A-Za-z0-9_]+\([^{]*\)\s*{)\s*{\s*return\s+\{\};', r'\1 \2 return {};', content)

    # I need to be more careful. Let's just fix it universally:
    # We want `List<Recipe> _getMockRecipes() { { return [];`
    # to become `List<Recipe> _getMockRecipes() { return [];`
    
    # regex for `_getMockSomething() { { return [];`
    content = re.sub(r'(_getMock[A-Za-z0-9_]+\([^{]*\)\s*)\{\s*\{\s*return\s+(.*?);', r'\1{ return \2;', content)
    
    with open('lib/services/supabase_service.dart', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    fix_clean()
