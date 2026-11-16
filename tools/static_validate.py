"""Dependency-free packaging checks. NOT a Godot runtime or GDScript parser."""
from pathlib import Path
from urllib.parse import unquote
import re, sys
ROOT=Path(__file__).resolve().parent.parent
bad=[]
files=[p for p in ROOT.rglob('*') if p.is_file()]
paths={p.relative_to(ROOT).as_posix() for p in files}
for file in files:
    if file.suffix in ('.tscn','.tres','.gd','.godot'):
        text=file.read_text(encoding='utf8')
        for p in re.findall(r'res://([^\"\n\r]+)',text):
            path=p.rstrip(')')
            if path not in paths and not path.startswith('.godot/'):
                bad.append(f'{file.relative_to(ROOT)}: missing resource: res://{path}')
    if file.suffix=='.md':
        s=file.read_text(encoding='utf8')
        for link in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)',s):
            if link.startswith(('http:', 'https:', '#','mailto:')): continue
            resolved=(file.parent/unquote(link.split('#')[0])).resolve()
            if not resolved.exists():
                bad.append(f'{file.relative_to(ROOT)}: broken md link: {link}')
        for link in re.findall(r'!\[[^\]]*\]\(([^)]+)\)',s):
            if link.startswith(('http:', 'https:')):continue
            resolved=(file.parent/unquote(link.split('#')[0])).resolve()
            if not resolved.exists():bad.append(f'{file.relative_to(ROOT)}: broken image: {link}')
if bad:
    print('STATIC VALIDATION FAILED:')
    for x in bad:print('-',x)
    sys.exit(1)
print(f'STATIC VALIDATION PASSED: {len(files)} files, relative Markdown links and Godot res:// paths resolve.')
print('LIMITATION: No actual Godot 4.7.2 scene import, compile or gameplay tests performed.')
