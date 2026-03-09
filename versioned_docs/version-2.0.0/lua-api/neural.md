---
title: Neural Network
description: Neural network functions for machine learning
keywords: [Lua, Neural Network, Machine Learning]
sidebar_position: 12
---
# Neural Network

:::danger Deprecated Feature
This functionality has been dropped in version 1.8.0 and is no longer available.
:::

```lua
local nauthilus_neural = require("nauthilus_neural")
```

## add_additional_features

Adds custom features to the authentication state for neural network processing. These features can be used by the neural network for more accurate brute force detection.

### Syntax

```lua
nauthilus_neural.add_additional_features(features_table, encoding_type)
```

### Parameters

- `features_table` (table): A table containing key-value pairs of features to add
- `encoding_type` (string, optional): The encoding type to use for string features. Valid values are:
  - `"one-hot"` (default): Uses one-hot encoding for string features
  - `"embedding"`: Uses embedding encoding for string features

### Notes

- The function does not return any values
- Features with keys "ClientIP", "client_ip", "Username", or "username" are automatically skipped
- If called multiple times, new features are merged with existing ones
- This function is available from Nauthilus version 1.7.7
- The experimental_ml feature must be enabled for these features to be used

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Add custom features with default one-hot encoding
nauthilus_neural.add_additional_features({
  user_agent = request.headers["User-Agent"],
  login_time = os.time(),
  device_type = "mobile",
  location = "office"
})

-- Add features with embedding encoding for string values
nauthilus_neural.add_additional_features({
  browser_info = request.headers["User-Agent"],
  referrer = request.headers["Referer"]
}, "embedding")
```

## set_learning_mode

Toggles the neural network learning mode on or off. When learning mode is enabled, the system collects data but does not use the neural network for predictions. When disabled, the system uses the trained neural network for predictions.

### Syntax

```lua
local learning_mode_state, error_message = nauthilus_neural.set_learning_mode(enabled)
```

### Parameters

- `enabled` (boolean): Whether to enable learning mode (true) or disable it (false)

### Returns

- `learning_mode_state` (boolean): The new learning mode state (true if in learning mode, false otherwise)
- `error_message` (string or nil): Error message if the operation failed, nil otherwise

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Enable learning mode
local is_learning, error = nauthilus_neural.set_learning_mode(true)
if error then
  print("Failed to enable learning mode: " .. error)
else
  print("Learning mode is now: " .. (is_learning and "enabled" or "disabled"))
end

-- Disable learning mode
local is_learning, error = nauthilus_neural.set_learning_mode(false)
if not error then
  print("Learning mode is now: " .. (is_learning and "enabled" or "disabled"))
end
```

### Notes

- This function is available from Nauthilus version 1.7.7
- The experimental_ml feature must be enabled for this function to work
- Learning mode affects how the system handles authentication attempts:
  - In learning mode: The system collects data for training but does not use the neural network for predictions
  - When not in learning mode: The system uses the trained neural network for predictions
- Cannot change learning mode when Dry-Run is activated in configuration

## get_learning_mode

Retrieves the current state of the neural network learning mode.

### Syntax

```lua
local learning_mode_state = nauthilus_neural.get_learning_mode()
```

### Parameters

None

### Returns

- `learning_mode_state` (boolean): The current learning mode state (true if in learning mode, false otherwise)

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Check current learning mode
local is_learning = nauthilus_neural.get_learning_mode()
print("Learning mode is currently: " .. (is_learning and "enabled" or "disabled"))

-- Use the learning mode state in conditional logic
if is_learning then
  print("System is collecting training data but not using neural network for predictions")
else
  print("System is using the trained neural network for predictions")
end
```

### Notes

- This function is available from Nauthilus version 1.7.19
- The experimental_ml feature must be enabled for this function to work
- Learning mode affects how the system handles authentication attempts:
  - In learning mode: The system collects data for training but does not use the neural network for predictions
  - When not in learning mode: The system uses the trained neural network for predictions

## train_neural_network

Manually trains the neural network model used for brute force detection.

### Syntax

```lua
local success, error_message = nauthilus_neural.train_neural_network(maxSamples, epochs)
```

### Parameters

- `maxSamples` (number, optional): Maximum number of training samples to use. Default: 5000
- `epochs` (number, optional): Number of training epochs. Default: 50

### Returns

- `success` (boolean): True if training was successful, false otherwise
- `error_message` (string or nil): Error message if training failed, nil otherwise

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Train with default parameters (5000 samples, 50 epochs)
local success, error = nauthilus_neural.train_neural_network()

if not success then
  print("Training failed: " .. error)
else
  print("Training completed successfully")
end

-- Train with custom parameters
local success, error = nauthilus_neural.train_neural_network(10000, 100)
```

### Notes

- This function is available from Nauthilus version 1.7.7
- Training the neural network requires the experimental_ml feature to be enabled
- Training is a resource-intensive operation and may take some time to complete
- The function uses data collected from previous authentication attempts

## reset_neural_network

Resets the neural network model to use only the canonical features from Redis. This is useful for fixing issues where the model's input size has grown too large or when you want to ensure all instances use a consistent set of features.

### Syntax

```lua
local success, error_message = nauthilus_neural.reset_neural_network()
```

### Parameters

None

### Returns

- `success` (boolean): True if the reset was successful, false otherwise
- `error_message` (string or nil): Error message if the reset failed, nil otherwise

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Reset the neural network model to canonical features
local success, error = nauthilus_neural.reset_neural_network()

if not success then
  print("Reset failed: " .. error)
else
  print("Neural network model reset successfully")
end
```

### Notes

- This function is available from Nauthilus version 1.7.20
- The experimental_ml feature must be enabled for this function to work
- This function resets the model to use only the canonical features stored in Redis
- All instances of Nauthilus will be notified of the reset via Redis pub/sub
- The reset operation is logged for auditing purposes

## remove_features_from_redis

Removes specified features from the canonical list in Redis for the neural network model. This is useful for removing features that are no longer needed or were added by mistake.

### Syntax

```lua
local success, error_message = nauthilus_neural.remove_features_from_redis(features_table)
```

### Parameters

- `features_table` (table): A table containing the names of features to remove

### Returns

- `success` (boolean): True if the features were removed successfully, false otherwise
- `error_message` (string or nil): Error message if the operation failed, nil otherwise

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Remove specific features from the canonical list
local features_to_remove = {"unused_feature", "noisy_feature", "redundant_feature"}
local success, error = nauthilus_neural.remove_features_from_redis(features_to_remove)

if not success then
  print("Failed to remove features: " .. error)
else
  print("Features removed successfully")
end
```

### Notes

- This function is available from Nauthilus version 1.7.20
- The experimental_ml feature must be enabled for this function to work
- After removing features, the model is automatically reset to use the updated canonical features
- All instances of Nauthilus will be notified of the changes via Redis pub/sub
- The operation is logged for auditing purposes

## provide_feedback

Provides feedback on neural network predictions to improve detection accuracy. This function allows administrators or security systems to correct false positives or false negatives, creating a feedback loop that continuously improves the neural network's performance.

### Syntax

```lua
local success, error_message = nauthilus_neural.provide_feedback(is_brute_force, request_id, client_ip, username)
```

### Parameters

- `is_brute_force` (boolean): Whether the login attempt was actually part of a brute force attack (true) or not (false)
- `request_id` (string): The request ID of the login attempt to provide feedback for
- `client_ip` (string): The client IP address of the login attempt
- `username` (string): The username of the login attempt

### Returns

- `success` (boolean): True if feedback was recorded successfully, false otherwise
- `error_message` (string or nil): Error message if recording feedback failed, nil otherwise

### Example

```lua
local nauthilus_neural = require("nauthilus_neural")

-- Provide feedback that a login attempt was NOT a brute force attack (false positive correction)
local success, error = nauthilus_neural.provide_feedback(false, "req-12345", "192.168.1.100", "john.doe")

if not success then
  print("Failed to record feedback: " .. error)
else
  print("Feedback recorded successfully")
end

-- Provide feedback that a login attempt WAS a brute force attack (false negative correction)
local success, error = nauthilus_neural.provide_feedback(true, "req-67890", "10.0.0.5", "admin")
```

### Notes

- This function is available from Nauthilus version 1.7.7
- The experimental_ml feature must be enabled for this function to work
- Feedback is prioritized in training to improve detection accuracy
- When sufficient feedback samples (10 or more) are collected, the system automatically retrains the neural network
- Feedback helps the system learn from its mistakes and continuously improve detection accuracy

## Custom Hook for Feedback

A custom hook is available to provide feedback on neural network predictions via HTTP. This allows you to correct false positives or false negatives remotely without direct server access.

### Configuration

Add the following to your Nauthilus configuration in the `lua.custom_hooks` section:

```yaml
lua:
  custom_hooks:
    - http_location: "neural-feedback"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/neural-feedback.lua"
      roles: ["admin"]  # Restrict access to admin users when JWT auth is enabled
```

### Usage

Once configured, you can provide feedback by making a GET request to:

```
/api/v1/custom/neural-feedback
```

#### Query Parameters

- `is_brute_force` (required): Whether the login attempt was actually part of a brute force attack. Valid values are:
  - `true` or `1` or `yes`: It was a brute force attack
  - `false` or `0` or `no`: It was not a brute force attack
- `request_id` (required): The request ID of the login attempt to provide feedback for
- `client_ip` (required): The client IP address of the login attempt
- `username` (required): The username of the login attempt

#### Example

```
GET /api/v1/custom/neural-feedback?is_brute_force=true&request_id=req-12345&client_ip=192.168.1.100&username=john.doe
```

This will provide feedback that the login attempt with request ID "req-12345" from IP "192.168.1.100" for username "john.doe" was actually part of a brute force attack.

### Response

The hook returns a JSON response with the result:

```json
{
  "status": "success",
  "message": "Feedback recorded successfully",
  "is_brute_force": true,
  "request_id": "req-12345",
  "client_ip": "192.168.1.100",
  "username": "john.doe"
}
```

Or in case of an error:

```json
{
  "status": "error",
  "message": "Failed to record feedback",
  "error": "Error message details",
  "is_brute_force": true,
  "request_id": "req-12345",
  "client_ip": "192.168.1.100",
  "username": "john.doe"
}
```

## How the Feedback System Works

The neural network feedback system creates a continuous improvement loop for brute force detection accuracy:

1. **Feedback Collection**: Administrators or security systems provide feedback on predictions through the Lua API or HTTP hook
2. **Prioritized Training**: Feedback samples are marked in the training data and prioritized during model retraining
3. **Automatic Retraining**: When 10 or more feedback samples are collected, the system automatically retrains the neural network
4. **Improved Accuracy**: The retrained model incorporates the feedback, reducing false positives and false negatives
5. **Learning Mode Transition**: If the system was in learning mode, collecting enough feedback can automatically transition it to prediction mode

### Benefits of the Feedback System

- **Continuous Improvement**: The system gets better over time as it learns from its mistakes
- **Reduced False Positives**: Fewer legitimate users are incorrectly flagged as attackers
- **Reduced False Negatives**: More actual attacks are correctly identified
- **Adaptive Learning**: The system adapts to your specific environment and threat patterns
- **Faster Training**: Feedback-triggered training uses more epochs (100 vs. 50) for better learning
- **Automatic Operation**: No manual intervention required once feedback is provided

### Implementation Details

The feedback system is implemented with the following components:

- **Feedback Storage**: Feedback samples are stored in Redis with a special flag
- **Prioritized Training**: The training algorithm gives special attention to feedback samples
- **Automatic Retraining**: A background process checks for feedback samples and triggers retraining
- **Model Persistence**: The improved model is saved to Redis for use by all Nauthilus instances
- **Learning Mode Management**: The system can automatically transition from learning to prediction mode

## Custom Hook for Training

A custom hook is available to trigger neural network training via HTTP. This allows you to train the model remotely without direct server access.

### Configuration

Add the following to your Nauthilus configuration in the `lua.custom_hooks` section:

```yaml
lua:
  custom_hooks:
    - http_location: "train-neural-network"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/train-neural-network.lua"
      roles: ["admin"]  # Restrict access to admin users when JWT auth is enabled
```

### Usage

Once configured, you can trigger training by making a GET request to:

```
/api/v1/custom/train-neural-network
```

#### Query Parameters

- `epochs` (optional): Number of training epochs. Default: 50
- `samples` (optional): Maximum number of samples to use. Default: 5000

#### Example

```
GET /api/v1/custom/train-neural-network?epochs=100&samples=10000
```

This will train the neural network using 10,000 samples for 100 epochs.

### Response

The hook returns a JSON response with the training result:

```json
{
  "status": "success",
  "message": "Neural network training completed successfully",
  "epochs": 100,
  "samples": 10000
}
```

Or in case of an error:

```json
{
  "status": "error",
  "message": "Neural network training failed",
  "error": "Error message details",
  "epochs": 100,
  "samples": 10000
}
```

## Custom Hook for Learning Mode

A custom hook is available to toggle the neural network learning mode via HTTP. This allows you to switch between learning and prediction modes remotely without direct server access.

### Configuration

Add the following to your Nauthilus configuration in the `lua.custom_hooks` section:

```yaml
lua:
  custom_hooks:
    - http_location: "learning-mode"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/learning-mode.lua"
      roles: ["admin"]  # Restrict access to admin users when JWT auth is enabled
```

### Usage

Once configured, you can toggle the learning mode by making a GET request to:

```
/api/v1/custom/learning-mode
```

#### Query Parameters

- `enabled` (required): Whether to enable learning mode. Valid values are:
  - `true` or `1`: Enable learning mode
  - `false` or `0`: Disable learning mode

#### Example

```
GET /api/v1/custom/learning-mode?enabled=true
```

This will enable learning mode, causing the system to collect data but not use the neural network for predictions.

```
GET /api/v1/custom/learning-mode?enabled=false
```

This will disable learning mode, causing the system to use the trained neural network for predictions.

### Response

The hook returns a JSON response with the result:

```json
{
  "status": "success",
  "message": "Learning mode set successfully",
  "learning_mode": true
}
```

Or in case of an error:

```json
{
  "status": "error",
  "message": "Failed to set learning mode",
  "error": "Error message details",
  "learning_mode": false
}
```

## Custom Hook for Distributed Brute Force Testing

A custom hook is available to test the distributed brute force detection system via HTTP. This allows you to simulate attacks and verify that they are properly detected.

### Configuration

Add the following to your Nauthilus configuration in the `lua.custom_hooks` section:

```yaml
lua:
  custom_hooks:
    - http_location: "distributed-brute-force-test"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/distributed-brute-force-test.lua"
      roles: ["admin"]  # Restrict access to admin users when JWT auth is enabled
```

### Usage

Once configured, you can use the hook with one of the following actions:

#### Simulate Attack

Simulates a distributed brute force attack by generating multiple IPs attempting to access the same account.

```
GET /api/v1/custom/distributed-brute-force-test?action=simulate_attack&username=testuser&num_ips=20&country_code=DE
```

##### Query Parameters

- `action` (required): Must be "simulate_attack"
- `username` (required): The username to target in the simulated attack
- `num_ips` (optional): Number of unique IP addresses to generate. Default: 20
- `country_code` (optional): Country code to associate with the attack (e.g., "DE", "US")

##### Response

```json
{
  "status": "success",
  "message": "Distributed brute force attack simulated successfully",
  "username": "testuser",
  "num_ips": 20,
  "country_code": "DE"
}
```

#### Check Detection

Checks if an attack was detected for a specific account.

```
GET /api/v1/custom/distributed-brute-force-test?action=check_detection&username=testuser
```

##### Query Parameters

- `action` (required): Must be "check_detection"
- `username` (required): The username to check

##### Response

```json
{
  "status": "success",
  "message": "Detection check completed",
  "username": "testuser",
  "detection_result": {
    "threat_level": 0.8,
    "account_under_attack": true,
    "attack_score": 20,
    "captcha_enabled": true,
    "rate_limit_enabled": true,
    "monitoring_mode": true,
    "is_captcha_account": false,
    "attack_detected": true
  }
}
```

#### Run Test

Runs a complete test by resetting protection measures, simulating an attack, and checking if it was detected.

```
GET /api/v1/custom/distributed-brute-force-test?action=run_test&username=testuser&num_ips=20&country_code=DE
```

##### Query Parameters

- `action` (required): Must be "run_test"
- `username` (required): The username to target in the simulated attack
- `num_ips` (optional): Number of unique IP addresses to generate. Default: 20
- `country_code` (optional): Country code to associate with the attack (e.g., "DE", "US")

##### Response

```json
{
  "status": "success",
  "message": "Test completed",
  "username": "testuser",
  "num_ips": 20,
  "country_code": "DE",
  "detection_result": {
    "threat_level": 0.8,
    "account_under_attack": true,
    "attack_score": 20,
    "captcha_enabled": false,
    "rate_limit_enabled": false,
    "monitoring_mode": true,
    "is_captcha_account": false,
    "attack_detected": true
  },
  "test_result": "PASS",
  "test_message": "Distributed brute force attack was successfully detected"
}
```

## Custom Hook for Distributed Brute Force Administration

A custom hook is available to administer the distributed brute force detection system via HTTP. This allows you to view metrics and reset protection measures.

### Configuration

Add the following to your Nauthilus configuration in the `lua.custom_hooks` section:

```yaml
lua:
  custom_hooks:
    - http_location: "distributed-brute-force-admin"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/distributed-brute-force-admin.lua"
      roles: ["admin"]  # Restrict access to admin users when JWT auth is enabled
```

### Usage

Once configured, you can use the hook with one of the following actions:

#### Get Metrics

Retrieves metrics about the current state of distributed brute force protection.

```
GET /api/v1/custom/distributed-brute-force-admin?action=get_metrics
```

##### Query Parameters

- `action` (optional): If not provided or set to "get_metrics", retrieves metrics

##### Response

```json
{
  "status": "success",
  "message": "Metrics retrieved successfully",
  "metrics": {
    "threat_level": 0.8,
    "attempts": 1250,
    "unique_ips": 500,
    "unique_users": 25,
    "ips_per_user": 20,
    "attacked_accounts": {
      "user1": 20,
      "user2": 15
    },
    "blocked_regions": ["CN", "RU"],
    "rate_limited_ips": ["192.168.1.1", "10.0.0.1"],
    "captcha_accounts": ["user1", "user3"],
    "settings": {
      "captcha_enabled": "true",
      "rate_limit_enabled": "true",
      "monitoring_mode": "true",
      "ml_threshold": "0.5"
    }
  }
}
```

#### Reset Protection

Resets all protection measures.

```
GET /api/v1/custom/distributed-brute-force-admin?action=reset_protection
```

##### Query Parameters

- `action` (required): Must be "reset_protection"

##### Response

```json
{
  "status": "success",
  "message": "Protection measures reset successfully"
}
```

#### Reset Account

Resets protection measures for a specific account.

```
GET /api/v1/custom/distributed-brute-force-admin?action=reset_account&username=testuser
```

##### Query Parameters

- `action` (required): Must be "reset_account"
- `username` (required): The username to reset

##### Response

```json
{
  "status": "success",
  "message": "Account reset successfully",
  "username": "testuser"
}
```
