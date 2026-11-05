"""Trace the existing cake silhouette to code-native paths; no new logo artwork."""
from pathlib import Path
import cv2
import numpy as np
root = Path(__file__).resolve().parents[1]
im = cv2.imdecode(np.fromfile(root/'assets/logo.jpg', dtype=np.uint8), cv2.IMREAD_COLOR)
# Original artwork is 1280 square; only the cake, not the lettering.
crop = im[280:650, 470:810]
mask = (crop[:,:,2] < 180).astype(np.uint8)*255
contours, _ = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
dart = ['Path cakePath() {', 'final p = Path()..fillType = PathFillType.evenOdd;']
paths = []
for contour in contours:
    if cv2.contourArea(contour) < 10: continue
    pts = cv2.approxPolyDP(contour, 0.65, True).reshape(-1,2).tolist()
    dart.append(f'p.moveTo({pts[0][0]}, {pts[0][1]});')
    dart.extend(f'p.lineTo({x}, {y});' for x,y in pts[1:])
    dart.append('p.close();')
    paths.append('M'+' L'.join(f'{x},{y}' for x,y in pts)+' Z')
dart += ['return p;', '}']
(root/'lib/cake_path.dart').write_text("import 'package:flutter/material.dart';\n"+'\n'.join(dart), encoding='utf-8')
# Center the same path within Android's safe splash-icon area.
xml = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="288dp" android:height="288dp" android:viewportWidth="720" android:viewportHeight="720"><group android:translateX="190" android:translateY="175"><path android:fillColor="#8061A8" android:fillType="evenOdd" android:pathData="'+ ' '.join(paths)+'"/></group></vector>'
(root/'android/app/src/main/res/drawable/splash_cake.xml').write_text(xml, encoding='utf-8')
