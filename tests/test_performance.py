# tests/test_performance.py
import pytest
from core.csv_repair import robust_csv_parse

@pytest.mark.benchmark(group="csv-parsing")
def test_large_dataset_parsing_speed(tmp_path, benchmark):
    """Stress tests the parser to ensure 100,000 rows parse efficiently."""
    csv_file = tmp_path / "large_dataset.csv"
    
    # Generate 100,000 rows
    headers = "StoreID,StoreName,Status,Region\n"
    rows = "\n".join([f"{i},Store {i},Active,North" for i in range(100000)])
    csv_file.write_text(headers + rows, encoding="utf-8")
    
    # Run through pytest-benchmark plugin
    result = benchmark(robust_csv_parse, str(csv_file))
    
    assert len(result["rows"]) == 100000
    assert len(result["headers"]) == 4
