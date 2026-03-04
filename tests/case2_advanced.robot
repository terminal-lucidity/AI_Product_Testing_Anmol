*** Settings ***
Library                 QWeb
Library                 String
Library                 BuiltIn
Library                 DateTime
Library                 Collections
Library                 ../resources/custom_keywords.py
Suite Setup             Setup Browser And Login
Test Setup              Create Clean Chat Session
Suite Teardown          Close All Browsers

*** Variables ***
${BASE_URL}                 https://robotic.copado.com/ai
${WORKSPACE_NAME}           robotic testing    

# Robust Locators
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
    [Documentation]    Verifies the AI agent remembers context (a provided code snippet) across multiple turns.
    [Tags]             ai_context
    Switch To Copado Expert
    
    Send Prompt And Wait    Here is my custom Apex class: public class TaxCalculator { public static Decimal getTax(Decimal amount) { return amount * 0.1; } }
    Send Prompt And Wait    Write a complete Apex unit test for that exact class.
    ${response}=            Get Last AI Response
    Should Contain          ${response}    TaxCalculator    ignore_case=True
    Validate Code Snippet Present    ${response}    class

TC003 - Test Response Formatting For Code Requests
    [Documentation]    Ensures the AI returns code by validating language-specific syntax presence.
    [Tags]             ai_formatting
    Switch To Copado Expert
    Send Prompt And Wait    Write a Salesforce Apex trigger on the Account object that sets the Rating field to 'Hot' before insert if the AnnualRevenue is greater than 100000.
    ${response}=            Get Last AI Response
    Validate Code Snippet Present    ${response}    trigger

TC004 - Test Edge Case And Invalid Input Handling
    [Documentation]    Sends garbage special characters and verifies graceful handling without system crashes.
    [Tags]             ai_edge
    Send Prompt And Wait    ___$$$!!!@@@
    ${response}=            Get Last AI Response
    Validate Graceful Error Handling    ${response}

TC005 - Test AI Performance With Complex Data-Driven Prompts
    [Documentation]    Uses a FOR loop and complex architectural scenarios to stress-test response times and generation limits.
    [Tags]             ai_performance    data_driven
    
    # Advanced, multi-layered architectural prompts
    @{PROMPTS}=             Create List    
    ...    Design a Salesforce CI/CD Git branching strategy for an enterprise with 3 parallel development streams and a strict hotfix routing requirement.
    ...    Compare the security and performance implications of using 'With Sharing' versus 'Without Sharing' in a Batch Apex class processing PII data.
    ...    Write a secure Salesforce Lightning Web Component (LWC) that queries Account data using an imperative Apex call, including proper error handling and wire decorators.
    
    FOR    ${prompt}    IN    @{PROMPTS}
        ${start_time}=      Get Current Date    result_format=epoch
        
        Send Prompt And Wait    ${prompt}
        
        ${end_time}=        Get Current Date    result_format=epoch
        
        # We might need a slightly higher SLA (e.g., 35 seconds) because architectural generation takes heavy compute power
        Calculate And Validate Performance    ${start_time}    ${end_time}    300
    END
TC006 - Test Complex Troubleshooting Analysis
    [Documentation]    Feeds the AI a complex system error with context constraints and validates multi-part reasoning.
    [Tags]             ai_reasoning    complex_prompt
    
    # A complex, multi-layered prompt mimicking a real senior developer scenario
    ${complex_prompt}=      Set Variable    Analyze this Salesforce deployment error: "System.LimitException: Too many SOQL queries: 101" occurring in an Account trigger during a bulk data load. Explain the exact root cause, identify the violated best practice, and provide a bulkified Apex code solution using a Map.
    
    Send Prompt And Wait    ${complex_prompt}
    ${response}=            Get Last AI Response
    
    # 1. Validate Semantic Reasoning: Did it figure out *why* it broke?
    @{expected_reasoning}=  Create List    bulkification    loop    map    limit
    Validate Ai Relevance   ${response}    ${expected_reasoning}
    
    # 2. Validate Code Execution: Did it actually write the fix?
    Validate Code Snippet Present    ${response}    apex
*** Keywords ***
Setup Browser And Login
    [Documentation]    Logs in and navigates to the workspace (runs once per suite).
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

Create Clean Chat Session
    [Documentation]    Opens a fresh chat and ensures the general DevOps expert is selected.
    ClickText          Create new chat    timeout=10s
    Sleep              2s
Send Prompt And Wait
    [Arguments]        ${message}
    [Documentation]    Types a message, clicks send, and waits reliably for the AI to finish generating.
    ClickElement       ${PROMPT_INPUT}
    TypeText           ${PROMPT_INPUT}             ${message}
    ClickElement       ${PROMPT_SEND}              timeout=20
    VerifyText         Stop generating             timeout=20
    VerifyNoElement    ${DISABLE_PROMPT_SEND}      timeout=220s    delay=5s

Get Last AI Response
    [Documentation]    Extracts the text from the most recent AI response bubble.
    ${text}=           GetText    ${LAST_AI_MESSAGE}
    RETURN             ${text}
Switch To Copado Expert
    [Documentation]    Forces the agent dropdown open and selects the Copado Expert.
    ${is_test_agent}=    IsText    Test Agent    timeout=3s
    
    IF  ${is_test_agent}
        ClickText    Test Agent
        Sleep        1s    
        ClickText    Copado Expert
        Sleep        1s    
        VerifyText   Copado Expert    timeout=5s
    END