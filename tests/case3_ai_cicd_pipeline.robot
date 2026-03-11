*** Settings ***
Documentation           Validate Copado AI Platform agents can orchestrate an end-to-end CI/CD workflow.
Resource                ../resources/common_keywords.robot
Library                 QWeb
Library                 QForce
Library                 String
Library                 Collections

Suite Setup             Setup Browser And Login And Ensure Workspace
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

*** Test Cases ***
TC001: Plan Agent - Create User Story
    [Documentation]    Use Plan Agent to create User Story and extract the ID for the pipeline.
    [Tags]             PlanAgent    Smoke
    Select AI Agent                Plan Agent
    Send Prompt And Wait For AI    ${PROMPT_CREATE_STORY}
    
    Extract User Story Details
    
    Log                            Final Extracted User Story ID: ${USER_STORY_ID}
    Log                            Final Extracted User Story URL: ${USER_STORY_URL}
    
    Verify User Story Via QForce   ${USER_STORY_ID}    ${USER_STORY_TITLE}
    
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
    
    Verify Org Credential Via QForce    ${CREDENTIAL_ID}


*** Keywords ***
Setup Browser And Login And Ensure Workspace
    [Documentation]    Groups suite setup actions. QForce will automatically use the org connection configured in your CRT Suite settings.
    Setup Browser And Login
    Ensure Test Workspace Exists    ${WORKSPACE_NAME}

Extract User Story Details
    [Documentation]    Parses the AI message robustly to extract ID, URL, and Title.
    ${chat_text}=      Get Last AI Response

    # Extract ID (e.g., a09... or US-0000001)
    ${extracted_ids}=  Get Regexp Matches    ${chat_text}    (a[0-9A-Za-z]{14,17}|US-\\d{7})
    Should Not Be Empty    ${extracted_ids}    msg=Failed to find User Story ID in AI response!
    Set Global Variable    ${USER_STORY_ID}    ${extracted_ids}[0]
    
    # Extract URL
    ${extracted_urls}=     Get Regexp Matches    ${chat_text}    (https://[A-Za-z0-9\\.\\-]+\\.(?:force\\.com|salesforce\\.com)[^\\s]+?${USER_STORY_ID})
    IF    ${extracted_urls}
        ${USER_STORY_URL}=     Set Variable    ${extracted_urls}[0]
    ELSE
        ${USER_STORY_URL}=     GetAttribute    locator=xpath=(//div[contains(@class, 'ai-message')])[last()]//a    attribute=href
    END
    Set Global Variable    ${USER_STORY_URL}    ${USER_STORY_URL}

    # Extract Title
    ${regex_pattern}=      Set Variable          (?i)(?:user\\s*story\\s*)?title:\\s*(.*?)(?=(?:user\\s*story\\s*id|direct\\s*salesforce\\s*url|status|project|as\\s*a|summary):|\\n|$)
    ${extracted_titles}=   Get Regexp Matches    ${chat_text}    ${regex_pattern}    1
    Should Not Be Empty    ${extracted_titles}   msg=Failed to extract the User Story Title!
    ${USER_STORY_TITLE}=   Strip String          ${extracted_titles}[0]
    Set Global Variable    ${USER_STORY_TITLE}   ${USER_STORY_TITLE}

Extract Org Credential Details
    [Documentation]    Pulls the Copado Org Credential ID from the AI's response.
    ${response}=       Get Last AI Response
    ${extracted_org_ids}=    Get Regexp Matches    ${response}    (a[0-9A-Za-z]{14,17})
    Should Not Be Empty      ${extracted_org_ids}    msg=Failed to return a valid Copado Org Credential ID!
    Set Global Variable      ${CREDENTIAL_ID}        ${extracted_org_ids}[0]

Verify User Story Via QForce
    [Arguments]            ${story_id}    ${expected_title}
    [Documentation]        Uses standard QForce SOQL execution to verify the record exists. Note the escaped \= in the query!
    ${records}=            Query Records    SELECT Id, Name, copado__User_Story_Title__c FROM copado__User_Story__c WHERE Id \= '${story_id}'
    
    # Convert the JSON records response to a flat string. This is the safest way to assert data existence instantly.
    ${records_str}=        Convert To String    ${records}
    Should Contain         ${records_str}       ${story_id}          msg=User Story ${story_id} was not found in Salesforce!
    Should Contain         ${records_str}       ${expected_title}    ignore_case=True    msg=Title in Salesforce does not match AI extraction!
    Log                    Successfully verified User Story data directly via QForce API!

Verify Org Credential Via QForce
    [Arguments]            ${credential_id}
    [Documentation]        Uses standard QForce SOQL execution to verify the Org Credential exists. Note the escaped \= in the query!
    ${records}=            Query Records    SELECT Id, Name FROM copado__Org__c WHERE Id \= '${credential_id}'
    
    ${records_str}=        Convert To String    ${records}
    Should Contain         ${records_str}       ${credential_id}    msg=Org Credential ${credential_id} was not found in Salesforce!
    Log                    Successfully verified Org Credential directly via QForce API!