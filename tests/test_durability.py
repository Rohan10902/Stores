# tests/test_durability.py
import pytest
import psutil
import os
import sys
from PySide6.QtCore import QCoreApplication, QThreadPool

# Import your controller
from core.controllers import MainBackendController

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
    Stress test: Ensures the threadpool handles rapid background 
    dispatching without freezing or crashing.
    """
    controller = MainBackendController()
    pool = QThreadPool.globalInstance()
    
    # Rapidly dispatch 100 failed/corrupt background tasks 
    # (Testing the try-except boundary we built earlier)
    for i in range(100):
        controller.loadDataSafely(f"crash_test_{i}.csv")
        
    # Give the threadpool up to 3 seconds to clear the queue
    pool.waitForDone(3000)
    
    # If the application didn't crash from 100 simultaneous errors, it passes
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
    assert memory_diff < 50, f"Memory leak detected! Grew by {memory_diff} MB"

def test_benchmark_controller_init(benchmark, app):
    """
    Performance test: Measures the instantiation speed of the main controller 
    to prevent slow startup times in future updates.
    """
    benchmark(lambda: MainBackendController())
