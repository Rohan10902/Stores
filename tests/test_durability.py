class MockAsyncRunner:
    def run_async(self, category, func, callback_success, *args):
        # Execute the task payload safely
        output = func(*args)
        
        # Handle both single return values and (status, result) tuples natively
        result = output[1] if isinstance(output, tuple) and len(output) == 2 else output
        
        if callback_success:
            callback_success(result)
