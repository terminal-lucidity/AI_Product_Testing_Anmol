*** Settings ***
Library                 QWeb
Library                 QImage
Library                 OperatingSystem
Library                 String
Library                 BuiltIn
Suite Setup             Setup Browser And Login
Suite Teardown          Close All Browsers

*** Variables ***
${BASE_URL}             https://robotic.copado.com/ai

*** Test Cases ***
Create A New Workspace
    [Documentation]    Verifies that a user can successfully create a new workspace.
    [Tags]             testgen    workspace_create
    VerifyText         Create Workspace
    ClickText          Create Workspace
    ${RANDOM_STR}=     Generate Random String    6    [LETTERS]
    ${WS_NAME}=        Set Variable    Workspace ${RANDOM_STR}
    Set Suite Variable    ${WORKSPACE_NAME}    ${WS_NAME}
    
    TypeText           Name      ${WORKSPACE_NAME}
    ClickText          Create
    VerifyText         ${WORKSPACE_NAME}    timeout=10s

Verify Workspace Listing And Persistence
    [Documentation]    Verifies that the newly created workspace persists and appears in the workspace list.
    [Tags]             testgen    workspace_listing
    GoTo               ${BASE_URL}
    VerifyText         Welcome
    VerifyText         ${WORKSPACE_NAME}

Delete Workspace And Cleanup
    [Documentation]    Verifies workspace deletion functionality and ensures test data is properly cleaned up.
    [Tags]             testgen    workspace_delete
    ClickText          ${WORKSPACE_NAME}
    ClickText          Workspace Details
    
    ClickElement       xpath=//*[contains(text(), 'Edit Workspace')]/ancestor-or-self::button/following-sibling::button
    
    ClickText          Delete Workspace
    VerifyText         Are you sure you want to delete
    ClickText          Delete
    
    GoTo               ${BASE_URL}
    VerifyNoText       ${WORKSPACE_NAME}    timeout=10s

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