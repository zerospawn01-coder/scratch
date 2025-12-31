"""
EA-AOL Setup Script
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding='utf-8') if readme_file.exists() else ""

# Read requirements
requirements_file = Path(__file__).parent / "requirements.txt"
requirements = []
if requirements_file.exists():
    requirements = requirements_file.read_text(encoding='utf-8').strip().split('\n')

setup(
    name="ea-aol",
    version="0.1.0",
    description="Energy-Aware AI Orchestration Language",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="EA-AOL Community",
    author_email="ea-aol@example.com",
    url="https://github.com/ea-aol/reference-implementation",
    license="BSD-2-Clause",
    
    packages=find_packages(exclude=['tests', 'examples', 'docs']),
    
    install_requires=requirements,
    
    extras_require={
        'dev': [
            'pytest>=7.4.0',
            'pytest-cov>=4.1.0',
            'black>=23.7.0',
            'flake8>=6.1.0',
            'mypy>=1.5.0',
        ],
        'docs': [
            'sphinx>=7.1.0',
            'sphinx-rtd-theme>=1.3.0',
        ],
    },
    
    python_requires='>=3.9',
    
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: BSD License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Topic :: Scientific/Engineering :: Artificial Intelligence',
        'Topic :: System :: Hardware',
    ],
    
    keywords='ai ml energy optimization gpu orchestration',
    
    project_urls={
        'Bug Reports': 'https://github.com/ea-aol/reference-implementation/issues',
        'Source': 'https://github.com/ea-aol/reference-implementation',
        'Documentation': 'https://ea-aol.readthedocs.io',
    },
)
