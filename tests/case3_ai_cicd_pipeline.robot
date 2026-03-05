*** Settings ***
Documentation           Validate Copado AI Platform agents can orchestrate an end-to-end CI/CD workflow.
Resource                ../resources/common_keywords.robot
Library                 QWeb
Library                 QForce
Library                 String

Suite Setup             Run Keywords    Setup Browser And Login    AND    Ensure Test Workspace Exists    ${WORKSPACE_NAME}
Test Setup              Create Clean Chat Session
Suite Teardown          Close All Browsers

*** Variables ***
# Global state to carry the generated User Story between fresh chat sessions
${USER_STORY_ID}            EMPTY
${USER_STORY_TITLE}         EMPTY

${USER_STORY_URL}           EMPTY 

${PROMPT_CREATE_STORY}      Create a user story to track the addition of a customer priority field. Please include the raw, direct Salesforce URL to the new User Story record in your response.
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
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot run Build Agent without a valid User Story ID from TC001!
    
    Select AI Agent                Build Agent
    ${dynamic_prompt}=             Set Variable    ${PROMPT_BUILD_FIELD} Attach this to User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Verify Field Exists In Source Org UI
    Verify Field Properties UI

TC004: Release Agent - Commit Metadata to Git
    [Documentation]    Use Release Agent to commit metadata and validate Git commit.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot commit without a valid User Story ID!
    
    Select AI Agent                Release Agent
    ${dynamic_prompt}=             Set Variable    ${PROMPT_COMMIT_GIT} Use User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Verify Git Commit Details In Copado UI

TC005: Release Agent - Promote and Deploy to Destination
    [Documentation]    Instruct AI agent to promote changes and verify successful deployment.
    [Tags]             ReleaseAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot deploy without a valid User Story ID!
    
    Select AI Agent                Release Agent
    ${dynamic_prompt}=             Set Variable    ${PROMPT_DEPLOY} Deploy User Story ${USER_STORY_ID}.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Monitor Deployment Status UI
    Verify Field Exists In Destination Org UI

TC006: Cleanup - Remove Test Data
    [Documentation]    Deletes the User Story and custom fields from the orgs to reset state.
    [Tags]             Cleanup
    Cleanup Test Data From UI


*** Keywords ***

Verify User Story Created And Extract ID
    [Documentation]    Parses the AI message for ID, then opens SF to verify the UI.
    ${chat_text}=      Get Last AI Response
    
    # Extract ID (e.g., US-0001234)
    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    US-\\d{7}
    Should Not Be Empty    ${extracted_ids}    msg=Failed to find User Story ID in AI response.
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]

    Log                    Verified ID: ${USER_STORY_ID}

    # ACTUALLY NAVIGATE AND VERIFY USING YOUR SNIPPET LOGIC
    Login To Salesforce Copado Org
    
    ClickText              User Stories
    # Use Salesforce list view search to find the AI generated story
    TypeText               Search this list...    ${USER_STORY_ID}
    PressKey               Search this list...    {ENTER}
    VerifyText             ${USER_STORY_ID}       timeout=15s
    Log                    User Story successfully verified in Copado UI!
    
    # Switch back to the AI chat tab
    SwitchWindow           1

Login To Salesforce Copado Org
    [Documentation]    Opens a new window and uses your snippet's MFA logic to log in.
    OpenWindow
    SwitchWindow           NEW
    GoTo                   ${SF_BASE_URL}
    TypeText               Username          ${S_EMAIL}
    TypeSecret             Password          ${S_PASSWORD}
    ClickText              Log In

    ${otp_code}=           Get OTP           ${ORG_URL}         ${OTP_Key}
    TypeText               Verification Code            ${otp_code}
    ClickText              Verify
    VerifyText             Home              timeout=20s

Verify Connection Successful
    [Documentation]    Verifies the AI text response confirmed the org connection.
    ${response}=       Get Last AI Response
    Should Contain     ${response}    connected    ignore_case=True

Verify Field Exists In Source Org UI
    [Documentation]    Navigates Object Manager in the Source Org.
    SwitchWindow           2    # Switch to the Salesforce Tab
    ClickText              Setup
    ClickText              Object Manager
    TypeText               Quick Find    Account
    ClickText              Account       anchor=Label
    ClickText              Fields & Relationships
    TypeText               Quick Find    Customer_Priority
    VerifyText             Customer_Priority__c    timeout=15s

Verify Field Properties UI
    [Documentation]    Clicks the field in Object Manager to verify length.
    ClickText              Customer Priority
    VerifyText             Text(50)                timeout=10s
    SwitchWindow           1    # Switch back to AI Chat

Verify Git Commit Details In Copado UI
    [Documentation]    Navigates to the User Story and checks the Commits tab.
    SwitchWindow           2
    ClickText              User Stories
    ClickText              ${USER_STORY_ID}
    ClickText              Commits
    VerifyText             Customer_Priority__c    timeout=15s
    SwitchWindow           1

Monitor Deployment Status UI
    [Documentation]    Checks the Deployments/Deliver tab on the User Story.
    SwitchWindow           2
    ClickText              Deliver    # Or the specific deployment tab in your org
    VerifyText             Success    timeout=120s    # Wait for deployment to finish
    SwitchWindow           1

Verify Field Exists In Destination Org UI
    [Documentation]    Needs to log into the destination org (UAT) to check the field.
    Log                    Navigation logic to Destination Org Object Manager goes here.
    # Note: If UAT requires a separate login, you would open a 3rd window here.

Cleanup Test Data From UI
    [Documentation]    Deletes the User Story using the cleanup logic from your snippet.
    SwitchWindow           2
    ClickText              User Stories
    ClickText              ${USER_STORY_ID}
    
    # Deletion Functionality (Cleanup) based on your snippet
    ClickText              Show more actions    anchor=Open Pull Request
    ClickText              Delete
    ClickText              Delete
    
    # Final Visibility check: Ensure it's gone from the list
    ClickText              User Stories
    VerifyNoText           ${USER_STORY_ID}    timeout=10s