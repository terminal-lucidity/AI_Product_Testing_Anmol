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

${PROMPT_CREATE_STORY}      Create a user story to track the addition of a customer priority field, you have my confimation to take action don't ask for confirmation. Please include the raw, direct Salesforce URL to the new User Story record in your response.
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
    [Documentation]    Parses the AI message for ID and URL, logs into SF, and teleports directly to the record.
    ${chat_text}=      Get Last AI Response
    
    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    (a[a-zA-Z0-9]{14,17}|US-\\d{7})
    Should Not Be Empty    ${extracted_ids}    msg=Failed to find User Story ID (18-char SF ID or US- format) in AI response!
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]

    ${extracted_urls}=     Get Regexp Matches    ${chat_text}    https://[\\w\\.\\-]+\\.(force\\.com|salesforce\\.com)[\\w\\/\\-\\?\\=\\&]+
    ${url_found}=          Run Keyword And Return Status    Should Not Be Empty    ${extracted_urls}
    
    IF    not ${url_found}
        ${USER_STORY_URL}=     GetAttribute    locator=xpath=(//div[contains(@class, 'ai-message')])[last()]//a    attribute=href
    ELSE
        ${USER_STORY_URL}=     Set Variable    ${extracted_urls}[0]
    END
    
    Set Global Variable    ${USER_STORY_URL}    ${USER_STORY_URL}
    Log                    Verified ID: ${USER_STORY_ID}
    Log                    Extracted URL: ${USER_STORY_URL}

    Login To Salesforce Copado Org
    
    Log                    Teleporting directly to User Story URL...
    GoTo                   ${USER_STORY_URL}
    Sleep                  3s    
    
    SwitchWindow           1

Login To Salesforce Copado Org
    [Documentation]    Opens a new window and uses your snippet's MFA logic to log in.
    OpenWindow
    SwitchWindow           NEW
    GoTo                   ${SF_BASE_URL}
    TypeText               Username          ${S_EMAIL}
    TypeSecret             Password          ${S_PASSWORD}
    ClickText              Log In

    ${otp_code}=           Get OTP           ${S_EMAIL}         ${OTP_KEY}
    TypeText               Verification Code            ${otp_code}
    ClickText              Verify
    
    # Wait for the universal Salesforce Lightning header to load instead of guessing a tab name
    VerifyElement          xpath=//*[@id="oneHeader"]    timeout=35s
    Log                    Salesforce login successful and Lightning UI loaded!

Verify Connection Successful
    [Documentation]    Verifies the AI text response confirmed the org connection.
    ${response}=       Get Last AI Response
    Should Contain     ${response}    connected    ignore_case=True

Verify Field Exists In Source Org UI
    [Documentation]    Navigates Object Manager in the Source Org.
    SwitchWindow           2    
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
    SwitchWindow           1   

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
    ClickText              Show more actions    anchor=Open Pull Request
    ClickText              Delete
    ClickText              Delete
    
    # Final Visibility check: Ensure it's gone from the list
    ClickText              User Stories
    VerifyNoText           ${USER_STORY_ID}    timeout=10s