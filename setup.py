from distutils.core import setup
from Cython.Build import cythonize


setup(
    name = 'pugixmltodict',
    version='0.1',
    description='A fast alternative to xmltodict library',
    url='https://github.com/sepeth/pugixmltodict',
    author='Doğan Çeçen',
    author_email='sepeth@gmail.com',

    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 2.7',
        'Topic :: Text Processing :: Markup :: XML',
    ],

    ext_modules = cythonize('*.pyx'),
)
