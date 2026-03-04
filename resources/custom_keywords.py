import time
import re
from robot.api import logger

class custom_keywords:
    
    # Keyword 1: Validates Relevance (TC001)
    def validate_ai_relevance(self, response_text, expected_keywords):
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

    # Keyword 2: Validates Edge Cases (TC004)
    def validate_graceful_error_handling(self, response_text):
        error_patterns = [
            r"System\.[\w]+Exception",  # Apex exceptions
            r"java\.lang\.",            # Java exceptions
            r"SQL syntax",              # Database errors
            r"Stack trace:"             # Generic stack traces
        ]
        for pattern in error_patterns:
            if re.search(pattern, response_text, re.IGNORECASE):
                error_msg = f"Security/Edge Case failure: AI leaked raw system error matching pattern '{pattern}'"
                logger.error(error_msg)
                raise AssertionError(error_msg)
                
        logger.info("Edge case validated: No raw system exceptions leaked.")
        return True

    # Keyword 3: Validates Performance (TC005)
    def calculate_and_validate_performance(self, start_time, end_time, max_seconds):
        elapsed_time = float(end_time) - float(start_time)
        logger.info(f"AI Response took: {elapsed_time:.2f} seconds.")
        if elapsed_time > float(max_seconds):
            raise AssertionError(f"Performance SLA breached! Took {elapsed_time:.2f}s (Max allowed: {max_seconds}s)")
        return elapsed_time

    # Keyword 4: Validates Code Generation (TC003)
    def validate_code_snippet_present(self, response_text, expected_type="class"):
        response_lower = response_text.lower()
        
        if expected_type.lower() == "trigger":
            code_markers = ["trigger ", " on ", "{", "}", ";"]
        elif expected_type.lower() == "class":
            code_markers = ["class ", "{", "}", ";"]
        else:
            code_markers = ["{", "}"] # Fallback
            
        missing_markers = [marker for marker in code_markers if marker not in response_lower]
        if len(missing_markers) > 1:
            error_msg = f"Expected {expected_type} code snippet not found. Missing syntax markers: {missing_markers}"
            logger.error(error_msg)
            raise AssertionError(error_msg)
            
        logger.info(f"Code snippet for {expected_type} successfully identified in the response text.")
        return True