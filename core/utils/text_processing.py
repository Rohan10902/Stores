import re
from typing import Dict, Any

# 1. Precompile regex constants at module load time for maximum speed
REGEX_WHITESPACE = re.compile(r'\s+')
REGEX_NON_PRINTABLE = re.compile(r'[\x00-\x1F\x7F-\x9F]')
REGEX_EMAIL = re.compile(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
REGEX_PHONE = re.compile(r'^\+?1?\s*\(?-*\.*(\d{3})\)?\.*-*\s*(\d{3})\.*-*\s*(\d{4})$')

def clean_cell_text(raw_text: Any) -> str:
    """Removes bad characters, strips boundaries, and normalizes internal spaces."""
    if not isinstance(raw_text, str):
        raw_text = str(raw_text) if raw_text is not None else ""
        
    text = REGEX_NON_PRINTABLE.sub('', raw_text)
    text = REGEX_WHITESPACE.sub(' ', text).strip()
    return text

def calculate_similarity(str1: str, str2: str) -> float:
    """Fast heuristics for duplicate detection using Jaccard index on trigrams."""
    if not str1 or not str2:
        return 0.0
    
    # Generate character n-grams (size 3)
    ngrams1 = set(str1[i:i+3] for i in range(len(str1)-2))
    ngrams2 = set(str2[i:i+3] for i in range(len(str2)-2))
    
    if not ngrams1 or not ngrams2:
        return 0.0
        
    intersection = len(ngrams1.intersection(ngrams2))
    union = len(ngrams1.union(ngrams2))
    
    return intersection / union
