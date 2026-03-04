import time
from robot.api import logger

class custom_keywords:
    
    def validate_ai_relevance(self, response_text, expected_keywords):
        """
        Validates that an AI response is relevant by checking for the presence
        of required keywords. Handles case-insensitivity.
        """
        response_lower = response_text.lower()
        missing_keywords = []
        
        for keyword in expected_keywords:
            if keyword.lower() not in response_lower:
                missing_keywords.append(keyword)
                
        if missing_keywords:
            error_msg = f"AI response lacked relevant context. Missing expected keywords: {missing_keywords}"
            logger.error(error_msg)
            raise AssertionError(error_msg)
            
        logger.info("AI response relevance validated successfully.")
        return True

    def verify_code_block_formatting(self, response_text):
        """
        Checks if the AI correctly formatted code snippets in the rendered UI.
        Copado AI's UI renders code blocks by prepending the language name 
        (e.g., 'APEX', 'BASH', 'JSON') before the code snippet.
        """
        # We check for common code block language headers rendered by the UI
        expected_ui_markers = ["APEX", "BASH", "JAVA", "XML", "JSON"]
        
        has_code_block = any(marker in response_text for marker in expected_ui_markers)
        
        if not has_code_block:
            error_msg = f"Expected a rendered code block, but no language markers (like {expected_ui_markers}) were found in the UI text."
            logger.error(error_msg)
            raise AssertionError(error_msg)
            
        logger.info("Code block formatting verified in rendered UI.")
        return True

    def calculate_and_validate_performance(self, start_time, end_time, max_seconds):
        """
        Calculates the AI response time and fails the test if it exceeds the SLA.
        """
        elapsed_time = float(end_time) - float(start_time)
        logger.info(f"AI Response took: {elapsed_time:.2f} seconds.")
        
        if elapsed_time > float(max_seconds):
            raise AssertionError(f"Performance SLA breached! Took {elapsed_time:.2f}s (Max allowed: {max_seconds}s)")
            
        return elapsed_time