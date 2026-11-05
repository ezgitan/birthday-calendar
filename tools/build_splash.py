"""Use the existing cake path and Chewy font for identical native/Flutter branding."""
from pathlib import Path
import xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from fontTools.pens.transformPen import TransformPen
import trace_logo

root = Path(__file__).resolve().parents[1]
font = TTFont(root/'assets/Chewy-Regular.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
scale = 38 / font['head'].unitsPerEm
names = [cmap[ord(c)] for c in 'iyi ki']
width = sum(glyphs[n].width for n in names)*scale
dart, svg = [], []
def nums(points): return ', '.join(f'{v:.4f}' for p in points for v in p)
class Pen(BasePen):
    def _moveTo(self,p):
        dart.append(f'p.moveTo({nums([p])});'); svg.append('M'+nums([p]))
    def _lineTo(self,p):
        dart.append(f'p.lineTo({nums([p])});'); svg.append('L'+nums([p]))
    def _curveToOne(self,a,b,c):
        dart.append(f'p.cubicTo({nums([a,b,c])});'); svg.append('C'+nums([a,b,c]))
    def _qCurveToOne(self,a,b):
        dart.append(f'p.quadraticBezierTo({nums([a,b])});'); svg.append('Q'+nums([a,b]))
    def _closePath(self):
        dart.append('p.close();'); svg.append('Z')
pen=Pen(glyphs)
x=(192-width)/2
for name in names:
    glyphs[name].draw(TransformPen(pen,(scale,0,0,-scale,x,171)))
    x+=glyphs[name].width*scale
(root/'lib/splash_word_path.dart').write_text("import 'package:flutter/material.dart';\nPath splashWordPath() { final p = Path();\n"+'\n'.join(dart)+'\nreturn p;\n}',encoding='utf-8')
target=root/'android/app/src/main/res/drawable/splash_cake.xml'
ns='{http://schemas.android.com/apk/res/android}'
cake=ET.parse(target).getroot().find('group/path').get(ns+'pathData')
target.write_text('<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="288dp" android:height="288dp" android:viewportWidth="288" android:viewportHeight="288"><group android:translateX="48" android:translateY="48"><group android:translateX="40" android:translateY="8" android:scaleX="0.329411765" android:scaleY="0.329411765"><path android:fillColor="#8061A8" android:fillType="evenOdd" android:pathData="'+cake+'"/></group><path android:fillColor="#8061A8" android:pathData="'+' '.join(svg)+'"/></group></vector>',encoding='utf-8')
