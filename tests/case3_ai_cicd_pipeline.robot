*** Settings ***
Library                 QWeb
Library                 String
Library                 BuiltIn
Library                 DateTime
Library                 Collections
Resource                ../resources/common_keywords.robot
Library                 ../resources/custom_keywords.py
Suite Setup             Run Keywords    Setup Browser And Login    AND    Ensure Test Workspace Exists    ${WORKSPACE_NAME}
Test Setup              Create Clean Chat Session
Suite Teardown          Close All Browsers
*** Variables ***
# Global variable to hold our state between clean chat sessions
${USER_STORY_ID}            EMPTY

*** Test Cases ***
TC01: Plan Agent - Create User Story
    [Documentation]    Use Plan Agent to create User Story and extract the ID for the pipeline.
    [Tags]             PlanAgent    Smoke
    Select AI Agent                Plan Agent
    Send Prompt And Wait For AI             ${PROMPT_CREATE_STORY}
    Wait For AI To Finish Generating
    Verify User Story Created And Extract ID

TC02: Build Agent - Connect to Source Org
    [Documentation]    Use Build Agent to connect to Dev environment and validate credentials.
    [Tags]             BuildAgent
    Select AI Agent                Build Agent
    # Assuming connection prompt goes here, or it relies on UI setup
    Connect To Source Org
    Verify Connection Successful

TC03: Build Agent - Create Custom Text Field
    [Documentation]    Send request to create a custom text field and validate metadata.
    [Tags]             BuildAgent
    # Failsafe: Ensure TC01 successfully grabbed an ID before trying to build
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot run Build Agent without a valid User Story ID from TC01!
    
    Select AI Agent                Build Agent
    
    # Dynamically inject the User Story ID so the clean chat session knows what to target
    ${dynamic_prompt}=             Set Variable    ${PROMPT_BUILD_FIELD} Attach this to User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI              ${dynamic_prompt}
    
    Wait For AI To Finish Generating
    Monitor Execution Progress
    Verify Field Exists In Source Org
    Verify Field Properties

TC04: Release Agent - Commit Metadata to Git
    [Documentation]    Use Release Agent to commit metadata and validate Git commit.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot commit without a valid User Story ID!
    
    Select AI Agent                Release Agent
    
    # Dynamically inject the User Story ID
    ${dynamic_prompt}=             Set Variable    ${PROMPT_COMMIT_GIT} Use User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI              ${dynamic_prompt}
    
    Wait For AI To Finish Generating
    Monitor Execution Progress
    Verify Git Commit Details

TC05: Release Agent - Promote and Deploy to Destination
    [Documentation]    Instruct AI agent to promote changes and verify successful deployment.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot deploy without a valid User Story ID!
    
    Select AI Agent                Release Agent
    
    # Dynamically inject the User Story ID
    ${dynamic_prompt}=             Set Variable    ${PROMPT_DEPLOY} Deploy User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI              ${dynamic_prompt}
    
    Wait For AI To Finish Generating
    Monitor Deployment Status
    Verify Field Exists In Destination Org

*** Keywords ***
Prepare Environment
    [Documentation]    Logs in and ensures the workspace is ready.
    Setup Browser And Login
    Ensure Test Workspace Exists    ${WORKSPACE_NAME}

Wait For AI To Finish Generating
    [Documentation]    Waits for the AI response to complete by looking for the Send button to become interactive/visible.
    Sleep              5s    # Give the AI a moment to start typing
    # Adjust this locator if Copado disables the send button during generation
    VerifyElement      //*[@id='ai-prompt-send']    timeout=60s
    Log                AI generation appears to have completed.

Verify User Story Created And Extract ID
    [Documentation]    Scrapes the last AI response to find the US-XXXXXXX format and saves it globally.
    VerifyText         created    timeout=10s
    
    # Grab all the text from the most recent chat bubble
    # (Adjust this XPath to match the exact class Copado uses for AI message bubbles)
    ${chat_text}=      GetText    xpath=(//div[contains(@class, 'chat-message') or contains(@class, 'ai-response')])[last()]
    
    # Use RegEx to find the Copado User Story format (e.g., US-0001234)
    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    US-\\d{7}
    
    # Ensure we actually found an ID
    Should Not Be Empty    ${extracted_ids}    msg=Failed to find a User Story ID (US-XXXXXXX) in the AI response!
    
    # Save it globally so TC03, TC04, and TC05 can use it!
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]
    Log                Successfully captured User Story: ${USER_STORY_ID}

# --- STUBS FOR BACKEND/METADATA VALIDATION (NEXT STEPS) ---

Connect To Source Org
    Log    Connecting to Dev environment...

Verify Connection Successful
    Log    Validating org connection...

Monitor Execution Progress
    Log    Polling Copado Actions API for job completion...

Verify Field Exists In Source Org
    Log    Querying Salesforce Tooling API/SOQL to ensure Customer_Priority__c exists...

Verify Field Properties
    Log    Checking field length is 50 via Salesforce metadata...

Verify Git Commit Details
    Log    Checking Copado API for the Git commit payload on ${USER_STORY_ID}...

Monitor Deployment Status
    Log    Waiting for Release agent to finish deployment...

Verify Field Exists In Destination Org
    Log    Querying destination org via Salesforce API...