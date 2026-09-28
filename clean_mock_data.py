import re

def clean_supabase_service():
    with open('lib/services/supabase_service.dart', 'r') as f:
        lines = f.readlines()

    out_lines = []
    
    in_mock_method = False
    brace_count = 0

    in_mock_variable = False
    
    for i, line in enumerate(lines):
        # 1. Strip the `_useMockData` boolean variables
        if 'bool get _useMockData' in line or 'set _useMockData' in line or 'bool get useMockData => _useMockData' in line:
            continue
            
        # 2. Strip `_useMockData = true/false` assignments
        if '_useMockData = true;' in line or '_useMockData = false;' in line:
            continue
            
        # 3. Strip mock variables like `List<Recipe>? _mockRecipes;`
        if re.search(r'(List|Map)<.*>\?\s*_mock.*?;', line):
            continue
            
        # 4. Remove `_getMock...` and `_mock...` variables completely using brace matching
        if not in_mock_method:
            # Check if this line starts a mock method
            if re.search(r'([A-Za-z0-9_<>]+)\s+_getMock[A-Za-z0-9_]+\(', line):
                in_mock_method = True
                brace_count = line.count('{') - line.count('}')
                continue
        else:
            brace_count += line.count('{') - line.count('}')
            if brace_count <= 0:
                in_mock_method = False
            continue
            
        # 5. Fix `if (_useMockData || !_isInitialized)`
        new_line = line.replace('if (_useMockData || !_isInitialized)', 'if (!_isInitialized)')
        new_line = new_line.replace('if (!_isInitialized || _useMockData)', 'if (!_isInitialized)')
        
        # 6. If we have a fallback that just returns `_getMock...`, we need to handle it.
        # But wait! If the fallback just calls `_getMock...`, and we delete `_getMock...`, we will get a compilation error!
        # Example: `return _getMockRecipes();` -> `return [];` or `return null;`
        
        # Replace `return _getMock...(args);` with `return [];` or `return null;`
        # But how do we know if it returns a List or an Object?
        if 'return _getMock' in new_line:
            # If it's assigning to a List or returning from a List method:
            # Let's replace it with a throw or return empty.
            # Actually, instead of removing the calls, it's safer to leave the _getMock methods but make them return empty!
            pass

    # Wait, the above logic is a bit risky if I don't replace the calls correctly.
    # Let's do a SAFER approach.

def safer_clean():
    with open('lib/services/supabase_service.dart', 'r') as f:
        content = f.read()

    # Make `_useMockData` permanently false and unchangeable.
    content = re.sub(r'bool get _useMockData => (true|false);', r'bool get _useMockData => false;', content)
    content = re.sub(r'bool _useMockData = (true|false);', r'bool _useMockData = false;', content)
    
    # Remove any assignments to `_useMockData`
    content = re.sub(r'_useMockData = true;', r'// removed', content)
    content = re.sub(r'_useMockData = false;', r'// removed', content)

    # Make every _getMock method return immediately!
    # Find all methods starting with _getMock
    # Example: List<Recipe> _getMockRecipes() {
    # Replace with: List<Recipe> _getMockRecipes() { return [];
    
    # regex to find: `Type _getMockSomething(...) {`
    # and insert `return [];` or `return null;` or `return <Map>[];`
    
    # I will write a custom regex replacement
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

    content = re.sub(r'([A-Za-z0-9_<>]+)\s+(_getMock[A-Za-z0-9_]+\([^{]*\)\s*{)', replacer, content)

    with open('lib/services/supabase_service.dart', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    safer_clean()
