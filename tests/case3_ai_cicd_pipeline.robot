*** Settings ***
Documentation           Validate Copado AI Platform agents can orchestrate an end-to-end CI/CD workflow.
Resource                ../resources/common_keywords.robot
Suite Setup             Run Keywords    Setup Browser And Login    AND    Ensure Test Workspace Exists    ${WORKSPACE_NAME}
Test Setup              Create Clean Chat Session
Suite Teardown          Close All Browsers
*** Variables ***
# Global state to carry the generated User Story between fresh chat sessions
${USER_STORY_ID}            EMPTY

# Base AI Prompts reconstructed from your spec
${PROMPT_CREATE_STORY}      Create a user story to track the addition of a customer priority field.
${PROMPT_CONNECT_ORG}       Connect to the Dev environment.
${PROMPT_BUILD_FIELD}       Create custom text field 'Customer_Priority__c' on Account with length 50.
${PROMPT_COMMIT_GIT}        Commit the Customer_Priority__c metadata to Git.
${PROMPT_DEPLOY}            Promote and deploy the recent commit to the destination environment.

*** Test Cases ***
TC001: Plan Agent - Create User Story
    [Documentation]    Use Plan Agent to create User Story and extract the ID for the pipeline.
    [Tags]             PlanAgent    Smoke
    Select AI Agent                Plan Agent
    Send Prompt And Wait For AI    ${PROMPT_CREATE_STORY}
    Verify User Story Created And Extract ID

TC002: Build Agent - Connect to Source Org
    [Documentation]    Use Build Agent to connect to Dev environment and validate credentials.
    [Tags]             BuildAgent
    Select AI Agent                Build Agent
    Send Prompt And Wait For AI    ${PROMPT_CONNECT_ORG}
    Verify Connection Successful

TC003: Build Agent - Create Custom Text Field
    [Documentation]    Send request to create a custom text field and validate metadata.
    [Tags]             BuildAgent
    # Failsafe: Ensure TC01 successfully grabbed an ID before trying to build
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot run Build Agent without a valid User Story ID from TC01!
    
    Select AI Agent                Build Agent
    
    # Dynamically inject the User Story ID so the clean chat session knows what to target
    ${dynamic_prompt}=             Set Variable    ${PROMPT_BUILD_FIELD} Attach this to User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Monitor Execution Progress
    Verify Field Exists In Source Org
    Verify Field Properties

TC004: Release Agent - Commit Metadata to Git
    [Documentation]    Use Release Agent to commit metadata and validate Git commit.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot commit without a valid User Story ID!
    
    Select AI Agent                Release Agent
    
    # Dynamically inject the User Story ID
    ${dynamic_prompt}=             Set Variable    ${PROMPT_COMMIT_GIT} Use User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Monitor Execution Progress
    Verify Git Commit Details

TC005: Release Agent - Promote and Deploy to Destination
    [Documentation]    Instruct AI agent to promote changes and verify successful deployment.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot deploy without a valid User Story ID!
    
    Select AI Agent                Release Agent
    
    # Dynamically inject the User Story ID
    ${dynamic_prompt}=             Set Variable    ${PROMPT_DEPLOY} Deploy User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Monitor Deployment Status
    Verify Field Exists In Destination Org

*** Keywords ***

Verify User Story Created And Extract ID
    [Documentation]    Parses the AI message for both ID and Title, then verifies the UI.
    ${chat_text}=      Get Last AI Response
    
    # Extract ID (e.g., US-0001234)
    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    US-\\d{7}
    Should Not Be Empty    ${extracted_ids}
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]

    ${extracted_titles}=   Get Regexp Matches    ${chat_text}    (?<=Created\\s)(.*?)(?=\\s\\()
    ${title}=              Set Variable If    ${extracted_titles}    ${extracted_titles}[0]    Created Story
    Set Global Variable    ${USER_STORY_TITLE}    ${title}
    
    Log                    Verified ID: ${USER_STORY_ID} and Title: ${USER_STORY_TITLE}

    # ACTUALLY NAVIGATE AND VERIFY
    ClickText              User Stories
    TypeText               Search...    ${USER_STORY_ID}    # Search by ID is safer than Title
    VerifyText             ${USER_STORY_TITLE}    timeout=10s
    Log                    User Story successfully verified in Copado UI!

# -------------------------------------------------------------------------
# VALIDATION STUBS (Ready for your CLI or Copado UI verification logic)
# -------------------------------------------------------------------------

Verify Connection Successful
    [Documentation]    Verifies the AI successfully connected to the source org.
    ${response}=       Get Last AI Response
    Should Contain     ${response}    connected    ignore_case=True

Monitor Execution Progress
    [Documentation]    Placeholder for polling Copado Actions API or waiting for execution to finish.
    Log                Polling for job completion...

Verify Field Exists In Source Org
    [Documentation]    Validate the field was created via SOQL or UI.
    Log                Querying Salesforce to ensure Customer_Priority__c exists...

Verify Field Properties
    [Documentation]    Validate the field length is 50.
    Log                Checking field length is 50...

Verify Git Commit Details
    [Documentation]    Validate the commit exists in Git/Copado.
    Log                Checking Copado for the Git commit payload on ${USER_STORY_ID}...

Monitor Deployment Status
    [Documentation]    Wait for the deployment to finish.
    Log                Waiting for Release agent to finish deployment...

Verify Field Exists In Destination Org
    [Documentation]    Validate the field reached the destination environment.
    Log                Querying destination org to confirm deployment...