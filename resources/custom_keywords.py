import time
import re
from robot.api import logger


class custom_keywords:

    def validate_ai_relevance(self, response_text, expected_keywords, min_match_ratio=1.0):
        """
        Validate that the AI response contains a sufficient portion of the expected keywords.
        :param response_text: Full AI response as string
        :param expected_keywords: List of keywords/phrases expected in the response
        :param min_match_ratio: Float between 0 and 1 (e.g. 0.67 means 2/3 of keywords must be present)
        """
        if response_text is None:
            error_msg = "AI response was None."
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if not isinstance(response_text, str):
            error_msg = f"AI response must be a string. Got type: {type(response_text)}"
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if not response_text.strip():
            error_msg = "AI response was empty or whitespace only."
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if not expected_keywords:
            logger.info("No expected keywords provided; skipping relevance validation.")
            return True

        response_lower = response_text.lower()
        matched = []
        missing = []

        for keyword in expected_keywords:
            if not keyword:
                continue
            # Use word/phrase boundary-safe regex to avoid accidental substring matches
            pattern = r"\b" + re.escape(keyword.lower()) + r"\b"
            if re.search(pattern, response_lower):
                matched.append(keyword)
            else:
                missing.append(keyword)

        total = len(matched) + len(missing)
        match_ratio = (len(matched) / total) if total > 0 else 0.0

        logger.info(
            f"Relevance check results: matched={matched}, "
            f"missing={missing}, ratio={match_ratio:.2f}, "
            f"min_required={min_match_ratio}"
        )

        if match_ratio < float(min_match_ratio):
            error_msg = (
                f"AI response relevance too low. "
                f"Matched {len(matched)}/{total} keywords "
                f"(ratio={match_ratio:.2f}, required>={min_match_ratio}). "
                f"Missing: {missing}"
            )
            logger.error(error_msg)
            raise AssertionError(error_msg)

        logger.info("AI response relevance validated successfully.")
        return True

    def validate_graceful_error_handling(self, response_text, denied_patterns=None):
        """
        Validate that the AI response does not leak raw system errors, stack traces, or low-level exceptions.
        :param response_text: Full AI response
        :param denied_patterns: Optional list of regex patterns to treat as forbidden
        """
        if response_text is None:
            logger.info("AI response is None; no raw system errors detected.")
            return True

        if not isinstance(response_text, str):
            error_msg = f"AI response must be a string. Got type: {type(response_text)}"
            logger.error(error_msg)
            raise AssertionError(error_msg)

        default_patterns = [
            r"System\.[\w]+Exception",
            r"java\.lang\.\w+Exception",
            r"\bException in thread\b",
            r"Traceback \(most recent call last\):",
            r"\bat line \d+ of\b",
            r"SQL syntax error",
            r"ORA-\d{5}",
            r"Stack trace:",
            r"NullPointerException",
            r"ReferenceError:",
            r"TypeError:",
        ]

        error_patterns = denied_patterns if denied_patterns is not None else default_patterns

        for pattern in error_patterns:
            try:
                if re.search(pattern, response_text, re.IGNORECASE):
                    error_msg = (
                        f"Security/Edge Case failure: AI leaked raw system error "
                        f"matching pattern '{pattern}'"
                    )
                    logger.error(error_msg)
                    raise AssertionError(error_msg)
            except re.error as e:
                logger.error(f"Invalid regex pattern in denied_patterns: '{pattern}' ({e})")

        logger.info("Edge case validated: No raw system exceptions leaked.")
        return True

    def calculate_and_validate_performance(self, start_time, end_time, max_seconds):
        """
        Validate that the AI response time stays under an SLA threshold.
        :param start_time: Start timestamp (float or convertible to float)
        :param end_time: End timestamp (float or convertible to float)
        :param max_seconds: Max allowed duration in seconds
        :return: Elapsed time as float
        """
        try:
            start = float(start_time)
            end = float(end_time)
            max_allowed = float(max_seconds)
        except (TypeError, ValueError) as e:
            error_msg = f"Invalid numeric values for timing. Error: {e}"
            logger.error(error_msg)
            raise AssertionError(error_msg)

        elapsed_time = end - start
        logger.info(
            f"AI Response took: {elapsed_time:.3f} seconds "
            f"(max allowed: {max_allowed:.3f}s)."
        )

        if elapsed_time < 0:
            error_msg = (
                f"Measured negative elapsed time ({elapsed_time:.3f}s). "
                f"Check how start_time and end_time are captured."
            )
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if elapsed_time > max_allowed:
            raise AssertionError(
                f"Performance SLA breached! Took {elapsed_time:.3f}s "
                f"(Max allowed: {max_allowed:.3f}s)"
            )
        return elapsed_time

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
        
    def validate_context_retention(
        self,
        previous_user_message,
        previous_ai_response,
        current_user_message,
        current_ai_response,
        expected_references,
    ):
        """
        Validate that the AI retains important context across turns.
        :param previous_user_message: Prior user message content
        :param previous_ai_response: Prior AI response content
        :param current_user_message: Current user message content
        :param current_ai_response: Current AI response content
        :param expected_references: List of keywords/phrases that should appear in current_ai_response
                                    because of previous context.
        """
        if current_ai_response is None:
            error_msg = "Current AI response is None; cannot validate context retention."
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if not isinstance(current_ai_response, str):
            error_msg = (
                "Current AI response must be a string. "
                f"Got type: {type(current_ai_response)}"
            )
            logger.error(error_msg)
            raise AssertionError(error_msg)

        if not expected_references:
            logger.info(
                "No expected context references provided; skipping context retention validation."
            )
            return True

        resp_lower = current_ai_response.lower()
        missing_refs = []

        for ref in expected_references:
            if not ref:
                continue
            if ref.lower() not in resp_lower:
                missing_refs.append(ref)

        logger.info(
            f"Context retention check: expected_references={expected_references}, "
            f"missing={missing_refs}"
        )

        if missing_refs:
            error_msg = (
                "AI failed to retain conversation context. "
                f"Missing references in current response: {missing_refs}"
            )
            logger.error(error_msg)
            raise AssertionError(error_msg)

        logger.info("Conversation context retention validated successfully.")
        return True