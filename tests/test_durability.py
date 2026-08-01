# tests/test_durability.py
import pytest
from core.controllers.health_controller import HealthController

class MockAsyncRunner:
    """Bypasses QThreadPool to execute async tasks synchronously for unit testing."""
    def run_async(self, category, func, callback_success, *args):
        # Directly execute the task payload
        _, result = func(*args)
        callback_success(result)

def test_repeated_csv_loads_maintain_memory_stability(tmp_path):
    # Setup a mock CSV file
    csv_file = tmp_path / "stress.csv"
    csv_file.write_text("ID,Name\n1,Test Store", encoding="utf-8")
    
    # Initialize controller with mock runner and dummy callbacks
    mock_runner = MockAsyncRunner()
    controller = HealthController(
        async_runner=mock_runner, 
        notify_cb=lambda t, m, n: None, 
        say_cb=lambda t: None
    )
    
    # Simulate a user rapidly uploading 50 CSVs in a row
    for _ in range(50):
        controller.load_data(str(csv_file))
        
    # Verify the state represents exactly the last upload, not a concatenated mess
    assert controller._df is not None
    assert len(controller._df) == 1
    assert list(controller._df.columns) == ["ID", "Name"], "State was corrupted during repeated loads."
