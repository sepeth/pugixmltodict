# coding: utf-8
import sys
from distutils.core import setup, Extension


USE_CYTHON = False
CYTHON_PARAM = '--cython'
if CYTHON_PARAM in sys.argv:
    USE_CYTHON = True
    sys.argv.remove(CYTHON_PARAM)


SOURCE_EXT = '.pyx' if USE_CYTHON else '.cpp'
EXT_MODULES = [Extension(
    'pugixmltodict',
    sources=[
        'pugixmltodict' + SOURCE_EXT,
        'pugixml/src/pugixml.cpp',
    ],
)]

if USE_CYTHON:
    from Cython.Build import cythonize
    EXT_MODULES = cythonize(EXT_MODULES)


setup(
    name='pugixmltodict',
    version='0.1',
    description='A fast alternative to xmltodict library',
    url='https://github.com/sepeth/pugixmltodict',
    author='Doğan Çeçen',
    author_email='sepeth@gmail.com',

    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 2.7',
        'Topic :: Text Processing :: Markup :: XML',
    ],

    ext_modules=EXT_MODULES,
)
