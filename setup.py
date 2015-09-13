from distutils.core import setup
from Cython.Build import cythonize


setup(
    name = 'pugixmltodict',
    ext_modules = cythonize('*.pyx'),
)
