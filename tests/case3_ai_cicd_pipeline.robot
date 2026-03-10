*** Settings ***
Documentation           Validate Copado AI Platform agents can orchestrate an end-to-end CI/CD workflow.
Resource                ../resources/common_keywords.robot
Library                 QWeb
Library                 QForce
Library                 String
Library                 OperatingSystem
Suite Setup             Run Keywords    Install SF CLI On CRT    AND    Setup Browser And Login    AND    Ensure Test Workspace Exists    ${WORKSPACE_NAME}
Test Setup              Create Clean Chat Session
Suite Teardown          Close All Browsers

*** Variables ***
# Global state to carry the generated User Story between fresh chat sessions
${USER_STORY_ID}            EMPTY
${USER_STORY_TITLE}         EMPTY
${CREDENTIAL_ID}            EMPTY
${USER_STORY_URL}           EMPTY 

${PROMPT_CREATE_STORY}      Create a user story to track the addition of a customer priority field, you have my confimation to take action don't ask for confirmation. Please include the raw, direct Salesforce URL to the new User Story record in your response.
${PROMPT_CONNECT_BASE}      Connect to the Dev environment credential associated with User Story.
${PROMPT_BUILD_FIELD}       Create custom text field 'Customer_Priority__c' on Account with length 50.
${PROMPT_COMMIT_GIT}        Commit the Customer_Priority__c metadata to Git.
${PROMPT_DEPLOY}            Promote and deploy the recent commit to the destination environment.
${SF_TARGET_ORG}            Dev1-SFP
*** Test Cases ***
*** Test Cases ***
TC001: Plan Agent - Create User Story
    [Documentation]    Use Plan Agent to create User Story and extract the ID for the pipeline.
    [Tags]             PlanAgent    Smoke
    Select AI Agent                Plan Agent
    Send Prompt And Wait For AI    ${PROMPT_CREATE_STORY}
    
    Extract User Story Details
    
    Log                            Final Extracted User Story ID: ${USER_STORY_ID}
    Log                            Final Extracted User Story URL: ${USER_STORY_URL}
    
    Verify User Story              ${USER_STORY_ID}    ${USER_STORY_TITLE}
    
    Log To Console                 \n--- TC001 EXTRACTION RESULTS ---
    Log To Console                 USER_STORY_ID: ${USER_STORY_ID}
    Log To Console                 USER_STORY_URL: ${USER_STORY_URL}
    Log To Console                 ----------------------------------

TC002: Build Agent - Retrieve Source Org Credentials
    [Documentation]    Use Build Agent to fetch Dev environment credentials for the User Story.
    [Tags]             BuildAgent
    Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot connect without a valid User Story ID from TC001!
    
    Select AI Agent                Build Agent
    ${dynamic_prompt}=             Set Variable    Find the Org Credential details associated with User Story ${USER_STORY_ID}. Please provide the Org Credential ID.
    Send Prompt And Wait For AI    ${dynamic_prompt}
    
    Extract Org Credential Details
    
    Verify Org Credential          ${CREDENTIAL_ID}

# TC003: Build Agent - Create Custom Text Field
#     [Documentation]    Send request to create a custom text field and validate metadata.
#     [Tags]             BuildAgent
#     Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot run Build Agent without a valid User Story ID from TC001!
    
#     Select AI Agent                Build Agent
#     ${dynamic_prompt}=             Set Variable    ${PROMPT_BUILD_FIELD} Attach this to User Story ${USER_STORY_ID}.
#     Send Prompt And Wait For AI    ${dynamic_prompt}
    
#     Verify Field Exists In Source Org UI
#     Verify Field Properties UI

# TC004: Release Agent - Commit Metadata to Git
#     [Documentation]    Use Release Agent to commit metadata and validate Git commit.
#     [Tags]             ReleaseAgent
#     Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot commit without a valid User Story ID!
    
#     Select AI Agent                Release Agent
#     ${dynamic_prompt}=             Set Variable    ${PROMPT_COMMIT_GIT} Use User Story ${USER_STORY_ID}.
#     Send Prompt And Wait For AI    ${dynamic_prompt}
    
#     Verify Git Commit Details In Copado UI

# TC005: Release Agent - Promote and Deploy to Destination
#     [Documentation]    Instruct AI agent to promote changes and verify successful deployment.
#     [Tags]             ReleaseAgent
#     Should Not Be Equal            ${USER_STORY_ID}    EMPTY    msg=Cannot deploy without a valid User Story ID!
    
#     Select AI Agent                Release Agent
#     ${dynamic_prompt}=             Set Variable    ${PROMPT_DEPLOY} Deploy User Story ${USER_STORY_ID}.
#     Send Prompt And Wait For AI    ${dynamic_prompt}
    
#     Monitor Deployment Status UI
#     Verify Field Exists In Destination Org UI

# TC006: Cleanup - Remove Test Data
#     [Documentation]    Deletes the User Story and custom fields from the orgs to reset state.
#     [Tags]             Cleanup
#     Cleanup Test Data From UI


*** Keywords ***
Install SF CLI On CRT
    [Documentation]    Installs the Salesforce CLI into the local CRT workspace.
    Log                    Downloading and installing Salesforce CLI on the CRT runner...
    ${rc}    ${output}=    Run And Return Rc And Output    npm install @salesforce/cli
    Should Be Equal As Integers    ${rc}    0    msg=Failed to install SF CLI! Output: ${output}
    Log                    SF CLI installed successfully!

Extract User Story Details
    [Documentation]    Parses the AI message robustly to extract ID, URL, and Title.
    ${chat_text}=      Get Last AI Response

    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    (a[0-9A-Z][a-zA-Z0-9]{13,16}|US-\\d{7})
    Should Not Be Empty    ${extracted_ids}    msg=Failed to find User Story ID in AI response!
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]
    
    ${extracted_urls}=     Get Regexp Matches    ${chat_text}    (https://[A-Za-z0-9\\.\\-]+\\.(?:force\\.com|salesforce\\.com)[^\\s]+?${USER_STORY_ID})
    IF    ${extracted_urls}
        ${USER_STORY_URL}=     Set Variable    ${extracted_urls}[0]
    ELSE
        ${USER_STORY_URL}=     GetAttribute    locator=xpath=(//div[contains(@class, 'ai-message')])[last()]//a    attribute=href
    END
    Set Global Variable    ${USER_STORY_URL}    ${USER_STORY_URL}

    ${regex_pattern}=      Set Variable          (?i)(?:user\\s*story\\s*)?title:\\s*(.*?)(?=(?:user\\s*story\\s*id|direct\\s*salesforce\\s*url|status|project|as\\s*a|summary):|\\n|$)
    ${extracted_titles}=   Get Regexp Matches    ${chat_text}    ${regex_pattern}    1
    Should Not Be Empty    ${extracted_titles}   msg=Failed to extract the User Story Title!
    ${USER_STORY_TITLE}=   Strip String          ${extracted_titles}[0]
    Set Global Variable    ${USER_STORY_TITLE}   ${USER_STORY_TITLE}

Extract Org Credential Details
    [Documentation]    Pulls the Copado Org Credential ID from the AI's response.
    ${response}=       Get Last AI Response
    ${extracted_org_ids}=    Get Regexp Matches    ${response}    a11[A-Za-z0-9]{12,15}
    Should Not Be Empty      ${extracted_org_ids}    msg=Failed to return a valid Copado Org Credential ID!
    Set Global Variable      ${CREDENTIAL_ID}        ${extracted_org_ids}[0]

Verify User Story
    [Arguments]            ${story_id}    ${expected_title}
    [Documentation]        Queries the User Story via SF CLI and verifies the title matches.
    ${query}=              Set Variable    SELECT Id, Name, copado__User_Story_Title__c FROM copado__User_Story__c WHERE Id = '${story_id}'
    # Switched to npx sf to prevent path execution failures
    ${command}=            Set Variable    npx sf data query --query "${query}" --target-org ${SF_TARGET_ORG} --json
    ${output}=             Run SF CLI Command    ${command}
    Should Contain         ${output}    ${expected_title}    ignore_case=True    msg=User Story title not found in CLI output!
    Log                    Successfully verified User Story data directly via SF CLI!

Verify Org Credential
    [Arguments]            ${credential_id}
    [Documentation]        Queries the Copado Org Credential via SF CLI to ensure it exists.
    ${query}=              Set Variable    SELECT Id, Name FROM copado__Org__c WHERE Id = '${credential_id}'
    ${command}=            Set Variable    npx sf data query --query "${query}" --target-org ${SF_TARGET_ORG} --json
    ${output}=             Run SF CLI Command    ${command}
    Should Contain         ${output}    ${credential_id}    msg=Org Credential ID not found in CLI output!
    Log                    Successfully verified Org Credential directly via SF CLI!

Run SF CLI Command
    [Arguments]            ${command}
    [Documentation]        Executes an SF CLI command. Ensures we are logged in first.
    SF Login
    Log                    Executing SF CLI Command: ${command}
    ${rc}    ${output}=    Run And Return Rc And Output    ${command}
    Should Be Equal As Integers    ${rc}    0    msg=SF CLI command failed! Output: ${output}
    RETURN                 ${output}

SF Login
    [Documentation]        Authenticates the SF CLI robustly using a SOAP API Session ID pipe.
    # 1. Check if we are already authenticated to avoid unnecessary logins
    ${check_auth_rc}  ${check_auth_out}=    Run And Return Rc And Output    npx sf org display --target-org ${SF_TARGET_ORG}
    Return From Keyword If    ${check_auth_rc} == 0

    Log                    Target org not authenticated. Initiating SOAP API Login...
    ${otp_code}=           Get OTP    ${SF_BASE_URL}    ${OTP_KEY}

    # 2. Build the XML Payload
    ${xml_payload}=        Set Variable    <?xml version="1.0" encoding="utf-8" ?><env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><n1:login xmlns:n1="urn:partner.soap.sforce.com"><n1:username>${S_EMAIL}</n1:username><n1:password>${S_PASSWORD}${otp_code}</n1:password></n1:login></env:Body></env:Envelope>
    Create File            login_payload.xml    ${xml_payload}

    # 3. Execute the cURL request to Salesforce
    ${curl_cmd}=           Set Variable    curl -s -X POST -H "Content-Type: text/xml" -H "SOAPAction: login" -d @login_payload.xml ${SF_BASE_URL}/services/Soap/u/58.0
    ${rc}    ${output}=    Run And Return Rc And Output    ${curl_cmd}
    Remove File            login_payload.xml
    
    # 4. Safely extract the session ID with error checking
    ${session_ids}=        Get Regexp Matches    ${output}    <sessionId>(.*?)</sessionId>    1
    IF    not ${session_ids}
        Fail    Failed to retrieve Session ID! Salesforce responded with:\n${output}
    END
    ${session_id}=         Set Variable    ${session_ids}[0]
    
    # 5. Use 'echo |' instead of '< file.txt' to pipe the token to the CLI safely in the subshell
    ${login_cmd}=          Set Variable    echo "${session_id}" | npx sf org login access-token --set-default --alias ${SF_TARGET_ORG} --instance-url ${SF_BASE_URL} --no-prompt
    ${cli_rc}  ${cli_out}=  Run And Return Rc And Output    ${login_cmd}
    
    Should Be Equal As Integers    ${cli_rc}    0    msg=SF CLI Token Login failed! Output: ${cli_out}
    Log                    SF CLI authenticated successfully!

# Verify Field Exists In Source Org UI
#     [Documentation]    Navigates to the Copado Org Credential and uses it to log into the Dev Sandbox.
#     SwitchWindow           2
    
#     GoTo                   ${SF_BASE_URL}/lightning/r/copado__Org__c/${CREDENTIAL_ID}/view
    
#     VerifyText             Credential Name    timeout=15s
#     ClickText              Open Credential
    
#     SwitchWindow           NEW
#     VerifyElement          xpath=//*[@id\="oneHeader"]    timeout=30s
#     ${scratch_domain}=     ExecuteJavascript    return window.location.origin
    
#     GoTo                   ${scratch_domain}/lightning/setup/ObjectManager/home
    
#     VerifyText             Object Manager    timeout=15s
    
#     TypeText               Quick Find    Account
#     ClickText              Account       anchor=Label
#     ClickText              Fields & Relationships
#     TypeText               Quick Find    Customer_Priority
#     VerifyText             Customer_Priority__c    timeout=15s

# Verify Field Properties UI
#     [Documentation]    Clicks the field in Object Manager to verify length, then closes the org window.
#     ClickText              Customer Priority
#     VerifyText             Text(50)                timeout=10s
#     CloseWindow
#     SwitchWindow           1



# Verify Git Commit Details In Copado UI
#     [Documentation]    Navigates to the User Story and checks the Commits tab.
#     SwitchWindow           2
#     ClickText              User Stories
#     ClickText              ${USER_STORY_ID}
#     ClickText              Commits
#     VerifyText             Customer_Priority__c    timeout=15s
#     SwitchWindow           1

# Monitor Deployment Status UI
#     [Documentation]    Checks the Deployments/Deliver tab on the User Story.
#     SwitchWindow           2
#     ClickText              Deliver    # Or the specific deployment tab in your org
#     VerifyText             Success    timeout=120s    # Wait for deployment to finish
#     SwitchWindow           1

# Verify Field Exists In Destination Org UI
#     [Documentation]    Needs to log into the destination org (UAT) to check the field.
#     Log                    Navigation logic to Destination Org Object Manager goes here.
#     # Note: If UAT requires a separate login, you would open a 3rd window here.

# Cleanup Test Data From UI
#     [Documentation]    Deletes the User Story using the cleanup logic from your snippet.
#     SwitchWindow           2
#     ClickText              User Stories
#     ClickText              ${USER_STORY_ID}
#     ClickText              Show more actions    anchor=Open Pull Request
#     ClickText              Delete
#     ClickText              Delete
    
#     # Final Visibility check: Ensure it's gone from the list
#     ClickText              User Stories
#     VerifyNoText           ${USER_STORY_ID}    timeout=10s