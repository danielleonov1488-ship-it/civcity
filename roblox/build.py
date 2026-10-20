# Сборка места Roblox из файлов кода: src/ → build/StealALegion.rbxlx (открывается в Roblox Studio).
#   src/<Служба>/Имя.server.luau → Script, Имя.client.luau → LocalScript, Имя.luau → ModuleScript,
#   папки внутри служб → Folder (StarterPlayerScripts и StarterCharacterScripts — свои классы).
# Карта не хранится в файле: её строит сервер при запуске (ServerScriptService/World.luau).
# Запуск: python -I build.py
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'build', 'StealALegion.rbxlx')

SPECIAL_DIRS = {'StarterPlayerScripts': 'StarterPlayerScripts', 'StarterCharacterScripts': 'StarterCharacterScripts'}
SERVICE_PROPS = {
    # маленькая карта — подгрузка по частям не нужна, всё видно сразу
    'Workspace': '<bool name="StreamingEnabled">false</bool>',
}

_ref = 0


def ref():
    global _ref
    _ref += 1
    return 'RBX%08X' % _ref


def cdata(text):
    return '<![CDATA[' + text.replace(']]>', ']]]]><![CDATA[>') + ']]>'


def script_item(path, name, cls, indent):
    with open(path, encoding='utf-8') as f:
        source = f.read()
    pad = '\t' * indent
    return (f'{pad}<Item class="{cls}" referent="{ref()}">\n'
            f'{pad}\t<Properties>\n'
            f'{pad}\t\t<string name="Name">{escape(name)}</string>\n'
            f'{pad}\t\t<ProtectedString name="Source">{cdata(source)}</ProtectedString>\n'
            f'{pad}\t</Properties>\n'
            f'{pad}</Item>\n')


def folder_items(path, indent):
    out = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            cls = SPECIAL_DIRS.get(entry, 'Folder')
            pad = '\t' * indent
            out.append(f'{pad}<Item class="{cls}" referent="{ref()}">\n{pad}\t<Properties>\n'
                       f'{pad}\t\t<string name="Name">{escape(entry)}</string>\n{pad}\t</Properties>\n')
            out.extend(folder_items(full, indent + 1))
            out.append(f'{pad}</Item>\n')
        elif entry.endswith('.server.luau'):
            out.append(script_item(full, entry[:-len('.server.luau')], 'Script', indent))
        elif entry.endswith('.client.luau'):
            out.append(script_item(full, entry[:-len('.client.luau')], 'LocalScript', indent))
        elif entry.endswith('.luau'):
            out.append(script_item(full, entry[:-len('.luau')], 'ModuleScript', indent))
    return out


def main():
    parts = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n']
    services = sorted(os.listdir(SRC))
    if 'Workspace' not in services:
        services.append('Workspace')
    for service in services:
        full = os.path.join(SRC, service)
        extra = SERVICE_PROPS.get(service, '')
        parts.append(f'\t<Item class="{service}" referent="{ref()}">\n\t\t<Properties>\n'
                     f'\t\t\t<string name="Name">{service}</string>\n'
                     + (f'\t\t\t{extra}\n' if extra else '') + '\t\t</Properties>\n')
        if os.path.isdir(full):
            parts.extend(folder_items(full, 2))
        parts.append('\t</Item>\n')
    parts.append('</roblox>\n')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(''.join(parts))
    n = sum(1 for p in parts if 'ProtectedString' in p)
    print(f'собрано: {OUT} ({n} скриптов, {os.path.getsize(OUT) // 1024} КБ)')


if __name__ == '__main__':
    sys.exit(main())
