import glob
import os
import sys

from setuptools import setup
from distutils.sysconfig import get_python_lib


if os.path.exists('README.md'):
    print("""The setup.py script should be executed from the build directory.

Please see the file 'README.md' for further instructions.""")
    sys.exit(1)


setup(
    name = "libasynctasks",
    package_dir = {
        '': 'src'
    },
    data_files = [
        (get_python_lib(), glob.glob('src/*.so')),
    ],
    author = 'Caleb Marshall',
    description = 'A fast, efficient task based system for concurrency.',
    license = 'BSD 3-Clause',
    keywords = 'cmake cython build',
    url = 'https://github.com/AnythingTechPro/libasynctasks',
    zip_safe = False
)
