#!/usr/bin/env python3
"""Generate native light/dark color assets from the canonical SwiftUI token file."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
spec=json.loads((root/'App/Resources/design-tokens.json').read_text())
asset=root/'App/Resources/DesignColors.xcassets';asset.mkdir(exist_ok=True)
(asset/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
for name,value in spec['color'].items():
    colors=[]
    for appearance,hexvalue in [(None,value),('dark',spec['darkColor'][name])]:
        color={'idiom':'universal','color':{'color-space':'srgb','components':{c:f'{int(hexvalue.lstrip("#")[i:i+2],16)/255:.6f}' for c,i in [('red',0),('green',2),('blue',4)]}}}
        color['color']['components']['alpha']='1.000'
        if appearance: color['appearances']=[{'appearance':'luminosity','value':appearance}]
        colors.append(color)
    target=asset/(name+'.colorset');target.mkdir(exist_ok=True)
    (target/'Contents.json').write_text(json.dumps({'colors':colors,'info':{'author':'xcode','version':1}},indent=2)+'\n')
print(f'{len(spec["color"])} native color roles generated')
