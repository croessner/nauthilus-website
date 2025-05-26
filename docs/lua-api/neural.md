---
title: Neural Network
description: Neural network functions for machine learning
keywords: [Lua, Neural Network, Machine Learning]
sidebar_position: 12
---
# Neural Network

```lua
dynamic_loader("nauthilus_neural")
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
dynamic_loader("nauthilus_neural")
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
dynamic_loader("nauthilus_neural")
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
