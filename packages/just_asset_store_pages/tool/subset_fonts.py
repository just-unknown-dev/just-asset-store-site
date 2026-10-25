"""Makes the static pages' fonts: the design package's faces, cut to the
Latin characters the pages use, as WOFF2 (about a tenth of the size).

    python tool/subset_fonts.py

Needs fonttools and brotli (pip install fonttools brotli). Run it again
when the design package's fonts change; the files are committed.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', '..', 'just_unknown_design', 'assets', 'fonts')
OUT = os.path.join(HERE, '..', 'lib', 'src', 'fonts')

# Google Fonts' "latin" range, plus the arrows the pages draw.
UNICODES = ','.join([
    'U+0000-00FF', 'U+0131', 'U+0152-0153', 'U+02BB-02BC', 'U+02C6', 'U+02DA',
    'U+02DC', 'U+0304', 'U+0308', 'U+0329', 'U+2000-206F', 'U+20AC',
    'U+2122', 'U+2190-2199', 'U+2212', 'U+2215', 'U+FEFF', 'U+FFFD',
])

FACES = [
    'Inter-Regular', 'Inter-Medium', 'Inter-SemiBold',
    'SpaceGrotesk-Medium', 'SpaceGrotesk-Bold', 'JetBrainsMono-Regular',
]

os.makedirs(OUT, exist_ok=True)
for face in FACES:
    subprocess.run([
        sys.executable, '-m', 'fontTools.subset',
        os.path.join(SRC, face + '.ttf'),
        '--unicodes=' + UNICODES,
        '--layout-features=*',
        '--flavor=woff2',
        '--output-file=' + os.path.join(OUT, face + '.woff2'),
    ], check=True)
    print(face, os.path.getsize(os.path.join(OUT, face + '.woff2')), 'bytes')
for licence in ('OFL-Inter.txt', 'OFL-SpaceGrotesk.txt', 'OFL-JetBrainsMono.txt'):
    shutil.copyfile(os.path.join(SRC, licence), os.path.join(OUT, licence))
