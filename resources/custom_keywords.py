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
        Checks if the AI correctly formatted code snippets using Markdown formatting (```).
        """
        if "```" not in response_text:
            error_msg = "Expected Markdown code block formatting (```) was not found in the response."
            logger.error(error_msg)
            raise AssertionError(error_msg)
            
        logger.info("Code block formatting verified.")
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