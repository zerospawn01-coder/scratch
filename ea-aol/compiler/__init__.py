"""
EA-AOL Compiler Package
"""

from .parser import Parser, ParsedDeclaration, ParserError, parse_ea_aol
from .ir_builder import IRBuilder, EA_IR, build_ir

__version__ = "0.1.0"
__all__ = [
    'Parser', 'ParsedDeclaration', 'ParserError', 'parse_ea_aol',
    'IRBuilder', 'EA_IR', 'build_ir'
]
