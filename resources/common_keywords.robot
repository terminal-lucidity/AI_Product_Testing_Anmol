*** Settings ***
Library                 QWeb
Library                 String
Library                 BuiltIn
*** Variables ***
${BASE_URL}                 https://robotic.copado.com/ai
${WORKSPACE_NAME}           robotic testing    

*** Keywords ***
Setup Browser And Login
    [Documentation]    Opens browser and handles authentication only.
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

Ensure Test Workspace Exists
    [Arguments]        ${name}
    [Documentation]    Navigates to the workspace. If missing, creates it.
    GoTo               ${BASE_URL}
    ${exists}=         Run Keyword And Return Status    VerifyText    ${name}    timeout=5s
    
    IF  not ${exists}
        ClickText      Create Workspace
        TypeText       Name      ${name}
        ClickText      Create
        VerifyText     ${name}    timeout=10s
    END
    ClickText          ${name}

Create Clean Chat Session
    [Documentation]    Opens a fresh chat to prevent AI context hallucination.
    ClickText          Create new chat    timeout=10s
    Sleep              2s