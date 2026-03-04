*** Settings ***
Library    QWeb
Library    QImage
Library    OperatingSystem
Suite Setup             Open Browser    about:blank    chrome    --guest
Suite Teardown          Close All Browsers

*** Test Cases ***
Workspace Management Testing
    [Documentation]    Verifies that the Copado AI Platform allows users to create, view, and delete workspaces correctly.

    # Steps 1-14: Login and navigation (keeping as-is)
    GoTo   https://robotic.copado.com/ai
    VerifyText     Log in to Copado
    ClickText      Continue with Google
    VerifyText     Sign in
    TypeText       Email or phone    ${C_EMAIL}
    ClickText      Next
    VerifyText     Connecting to
    TypeText       Username          ${C_EMAIL}
    TypeSecret     Password          ${C_PASSWORD}
    ClickText      Sign In
    VerifyText     Okta Verify
    ClickText      Send Push         sleep=60s
    VerifyText     Welcome back      timeout=60s
    VerifyText     Project Overview