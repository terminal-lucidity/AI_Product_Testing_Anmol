*** Settings ***
Library                 QWeb
Library                 String
Library                 BuiltIn
Library                 DateTime
Library                 Collections
Library                 ../resources/custom_keywords.py
Suite Setup             Setup Browser And Login
Suite Teardown          Close All Browsers

*** Variables ***
${BASE_URL}                 https://robotic.copado.com/ai
${WORKSPACE_NAME}           robotic testing    

# Robust Locators from Reference Script
${PROMPT_INPUT}             xpath=//div[@id="ai-prompt-input"]
${PROMPT_SEND}              xpath=//button[@id="ai-prompt-send"]
${DISABLE_PROMPT_SEND}      xpath=//button[@id="ai-prompt-send" and @disabled]
${LAST_AI_MESSAGE}          xpath=(//div[contains(@class, 'ai-message')])[last()]

*** Test Cases ***
TC001 - Test Basic Dialogue And Relevance
    [Documentation]    Sends a domain-specific DevOps question and validates response relevance using custom Python logic.
    [Tags]             ai_core
    Send Prompt And Wait    What is Salesforce Copado used for?
    ${response}=            Get Last AI Response
    @{expected_words}=      Create List    devops    deployment    salesforce
    Validate Ai Relevance   ${response}    ${expected_words}

TC002 - Test Multi-Turn Conversation Context Retention
    [Documentation]    Verifies the AI agent remembers context from previous messages in the same thread.
    [Tags]             ai_context
    Send Prompt And Wait    I have a custom Apex class called "TaxCalculator".
    Send Prompt And Wait    Write a basic unit test for it.
    ${response}=            Get Last AI Response
    Should Contain          ${response}    TaxCalculator    ignore_case=True

TC003 - Test Response Formatting For Code Requests
    [Documentation]    Ensures the AI returns properly formatted markdown code blocks when asked for code.
    [Tags]             ai_formatting
    Send Prompt And Wait    Write a Salesforce Apex trigger on the Account object that sets the Rating field to 'Hot' before insert if the AnnualRevenue is greater than 100000.
    ${response}=            Get Last AI Response
    
    Verify Code Block Formatting    ${response}

TC004 - Test Edge Case And Invalid Input Handling
    [Documentation]    Sends garbage special characters and uses IF/ELSE to verify graceful handling without system crashes.
    [Tags]             ai_edge
    Send Prompt And Wait    ___$$$!!!@@@
    ${response}=            Get Last AI Response
    
    # Check if the AI gracefully asks for clarification or rejects it
    ${is_graceful}=         Run Keyword And Return Status    Should Contain    ${response}    clarify    ignore_case=True
    
    IF  ${is_graceful} == ${TRUE}
        Log    ✓ AI handled edge case gracefully by asking for clarification.    console=True
    ELSE
        Log    ✓ AI provided a standard fallback response. Checking for exceptions.    console=True
        Should Not Contain    ${response}    Exception    ignore_case=True  # Ensure no raw system errors leaked
    END

TC005 - Test AI Performance With Data-Driven Prompts
    [Documentation]    Uses a FOR loop and test data array to measure response times against an SLA.
    [Tags]             ai_performance    data_driven
    
    # Data-driven test data (embedded array)
    @{PROMPTS}=             Create List    What is CI/CD?    Explain metadata API    Compare Ant and SFDX
    
    FOR    ${prompt}    IN    @{PROMPTS}
        ${start_time}=      Get Current Date    result_format=epoch
        
        Send Prompt And Wait    ${prompt}
        
        ${end_time}=        Get Current Date    result_format=epoch
        
        # Custom Python Validation (Fails if calculation takes > 25 seconds)
        Calculate And Validate Performance    ${start_time}    ${end_time}    25
    END

*** Keywords ***
Setup Browser And Login
    [Documentation]    Opens the browser, navigates to the app, and handles the Okta/Google login flow.
    Open Browser       about:blank    chrome    --guest
    GoTo               ${BASE_URL}
    VerifyText         Log in to Copado
    ClickText          Continue with Google
    VerifyText         Sign in
    TypeText           Email or phone    ${C_EMAIL}
    ClickText          Next
    VerifyText         Connecting to
    TypeText           Username          ${C_EMAIL}
    TypeSecret         Password          ${C_PASSWORD}
    ClickText          Sign In
    VerifyText         Okta Verify
    ClickText          Send Push         sleep=60s
    VerifyText         Welcome           timeout=60s
    ClickText          ${WORKSPACE_NAME}

Send Prompt And Wait
    [Arguments]        ${message}
    [Documentation]    Types a message, clicks send, and waits reliably for the AI to finish generating.
    ClickElement       ${PROMPT_INPUT}
    TypeText           ${PROMPT_INPUT}             ${message}
    ClickElement       ${PROMPT_SEND}              timeout=20
    
    # Wait logic adapted from reference script for maximum stability
    VerifyText         Stop generating             timeout=20
    VerifyNoElement    ${DISABLE_PROMPT_SEND}      timeout=220s    delay=5s

Get Last AI Response
    [Documentation]    Extracts the text from the most recent AI response bubble.
    ${text}=           GetText    ${LAST_AI_MESSAGE}
    RETURN             ${text}