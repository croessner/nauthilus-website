---
title: TOTP page
description: TOTP registration website template
keywords: [TOTP, Registration, Template]
sidebar_position: 6
---
# TOTP page

You can customize the totp template. For this, you should use the default file **totp.html** and make changes as you
need.

There are several template fields that are required for Nauthilus to work.

## Fields and description

| Name                                                                                          | Description                                                                                                                    |
|-----------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| \{\{ .Title \}\}                                                                              | The page title shown in the browser tab                                                                                        |
| \{\{ if .WantWelcome \}\} \{\{ .Welcome \}\} \{\{ end \}\}                                    | A company name above the logo                                                                                                  |
| \{\{ .LogoImage \}\}                                                                          | The company logo                                                                                                               |
| \{\{ .LogoImageAlt \}\}                                                                       | The "alt" name for the company logo                                                                                            |
| \{\{ .TOTPMessage \}\}                                                                        | A descriptive text that asks the end user for scanning and verifying the TOTP QR code                                          |
| \{\{ .PostTOTPEndpoint \}\}                                                                   | This is the Nauthilus endpoint after entering a 6 digit code                                                                   |
| \{\{ .CSRFToken \}\}                                                                          | **Very important**: This field must be available in your template and the hidden input field must have the name **csrf_token** |
| \{\{ .Submit \}\}                                                                             | The text for the submit button                                                                                                 |
| \{\{ .LanguageCurrentName \}\}                                                                | The button name of the currently displayed language                                                                            |
| \{\{ range .LanguagePassive \}\} \{\{ .LanguageLink \}\} \{\{ LanguageName \}\} \{\{ end \}\} | This block is used to render alternative page languages                                                                        | 
| \{\{ if .HaveError \}\} \{\{ .ErrorMessage \}\} \{\{ end \}\}                                 | If an error occurred, display it to the user                                                                                   |
| \{\{ .LanguageTag \}\}                                                                        | The HTML **lang** attribute                                                                                                    |

The page template uses JavaScript to create a QR code for the TOTP code. You **must** provide something like the
following HTML snippet to get it displayed:

```html
<div id="canvas" data-raw="{{ .QRCode }}"></div>
```

The code is encoded in the variable \{\{ .QRCode \}\}. It folows the official Google draft.

| Name                                                                          | Description                                  |
|-------------------------------------------------------------------------------|----------------------------------------------|
| \{\{ if .WantTos \}\} \{\{ .TosUri \}\} \{\{ .Tos \}\} \{\{ end \}\}          | Display a terms of service link if available |
| \{\{ if .WantPolicy \}\} \{\{ .PolicyUri \}\} \{\{ .Policy \}\} \{\{ end \}\} | Display a policy link if available           |
