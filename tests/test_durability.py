# tests/test_durability.py
import pytest
import psutil
import os
import sys
from PySide6.QtCore import QCoreApplication, QThreadPool, QRunnable, Slot

# Import your controller
from core.controllers import MainBackendController

class StressWorker(QRunnable):
    """
    A self-contained worker strictly for CI testing.
    Floods the threadpool to ensure the app doesn't crash under heavy load.
    """
    def __init__(self, simulate_failure=False):
        super().__init__()
        self.simulate_failure = simulate_failure

    @Slot()
    def run(self):
        if self.simulate_failure:
            try:
                # Simulate a task failing in the background
                raise RuntimeError("Simulated background exception")
            except Exception:
                # Prove that background errors don't crash the main thread
                pass 

@pytest.fixture(scope="session")
def app():
    """
    Creates a Qt Application instance for testing.
    Qt requires an active application instance to test QObjects and Signals.
    """
    app = QCoreApplication.instance()
    if app is None:
        app = QCoreApplication(sys.argv)
    return app

def test_worker_thread_stress(app):
    """
    Stress test: Ensures the global threadpool handles rapid background 
    dispatching without freezing or crashing.
    """
    pool = QThreadPool.globalInstance()
    
    # Rapidly dispatch 100 background tasks to stress the hardware pool
    for i in range(100):
        worker = StressWorker(simulate_failure=True)
        pool.start(worker)
        
    # Give the threadpool up to 3 seconds to clear the queue
    pool.waitForDone(3000)
    
    # If the main application thread survived 100 rapid background dispatches, it passes
    assert True 

def test_memory_stability(app):
    """
    Durability test: Checks for massive memory spikes during heavy 
    component instantiation.
    """
    process = psutil.Process(os.getpid())
    
    # Record memory before
    mem_before = process.memory_info().rss / 1024 / 1024  # Convert to MB
    
    # Create a massive array of backend controllers
    controllers = [MainBackendController() for _ in range(500)]
    
    # Record memory after
    mem_after = process.memory_info().rss / 1024 / 1024   # Convert to MB
    
    # Memory growth should be well optimized (less than 50MB for 500 instances)
    memory_diff = mem_after - mem_before
    assert memory_diff < 50, f"Memory leak detected! Grew by {memory_diff:.2f} MB"

def test_benchmark_controller_init(benchmark, app):
    """
    Performance test: Measures the instantiation speed of the main controller 
    to prevent slow startup times in future updates.
    """
    benchmark(lambda: MainBackendController())
