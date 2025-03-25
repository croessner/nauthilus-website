---
title: Logout page
description: Logout website template
keywords: [OIDC, Logout, Template]
sidebar_position: 3
---
# Logout page

You can customize the logout template. For this, you should use the default file **logout.html** and make changes as
you need.

There are several template fields that are required for Nauthilus to work.

:::note
Not all applications do provide a logout endpoint
:::

## Fields and description

| Name                                                                                          | Description                                                                                                                                    |
|-----------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| \{\{ .Title \}\}                                                                              | The page title shown in the browser tab                                                                                                        |
| \{\{ if .WantWelcome \}\} \{\{ .Welcome \}\} \{\{ end \}\}                                    | A company name                                                                                                                                 |
| \{\{ .LogoutMessage \}\}                                                                      | A descriptive text that asks the end user to logout                                                                                            |
| \{\{ .PostLogoutEndpoint \}\}                                                                 | This is the Nauthilus endpoint for the Hydra server                                                                                            |
| \{\{ .CSRFToken \}\}                                                                          | **Very important**: This field must be available in your template and the hidden input field must have the name **csrf_token**                 |
| \{\{ .LogoutChallenge \}\}                                                                    | **Very important**: This field must be available in your template and the hidden input field must have the name **ory.hydra.logout_challenge** |
| \{\{ .AcceptSubmit \}\}                                                                       | Text for the accept button                                                                                                                     |
| \{\{ .RejectSubmit \}\}                                                                       | Text for the reject button                                                                                                                     |
| \{\{ .LanguageCurrentName \}\}                                                                | The button name of the currently displayed language                                                                                            |
| \{\{ range .LanguagePassive \}\} \{\{ .LanguageLink \}\} \{\{ LanguageName \}\} \{\{ end \}\} | This block is used to render alternative page languages                                                                                        | 
| \{\{ .LanguageTag \}\}                                                                        | The HTML **lang** attribute                                                                                                                    |
