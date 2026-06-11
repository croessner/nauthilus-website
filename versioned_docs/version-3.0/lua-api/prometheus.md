---
title: Prometheus
description: Prometheus functions for gauges, counter and histograms
keywords: [Lua]
sidebar_position: 10
---
# Prometheus

Nauthilus has basic support for some Prometheus metrics.

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")
```

## Gauge vector

You must create a gauge vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_gauge\_vec

Creates a Prometheus gauge vector with specified name, help text, and labels.

#### Syntax

```lua
nauthilus_prometheus.create_gauge_vec(name, help, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `help` (string): Description text for the gauge vector
- `labels` (table): A Lua table containing label names

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "http_client_concurrent_requests_total"
local help = "Measure the number of total concurrent HTTP client requests"
local labels = { "service" }

nauthilus_prometheus.create_gauge_vec(name, help, labels)
```

### nauthilus\_prometheus.add\_gauge

Adds a value to a gauge with specified labels.

#### Syntax

```lua
nauthilus_prometheus.add_gauge(name, value, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `value` (number): The value to add to the gauge
- `labels` (table): A Lua table containing label values

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.add_gauge(name, value, labels)
```

### nauthilus\_prometheus.sub\_gauge

Subtracts a value from a gauge with specified labels.

#### Syntax

```lua
nauthilus_prometheus.sub_gauge(name, value, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `value` (number): The value to subtract from the gauge
- `labels` (table): A Lua table containing label values

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.sub_gauge(name, value, labels)
```

### nauthilus\_prometheus.set\_gauge

Sets a gauge to a specific value with specified labels.

#### Syntax

```lua
nauthilus_prometheus.set_gauge(name, value, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `value` (number): The value to set the gauge to
- `labels` (table): A Lua table containing label values

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.set_gauge(name, value, labels)
```

### nauthilus\_prometheus.increment\_gauge

Increments a gauge counter by 1 with specified labels.

#### Syntax

```lua
nauthilus_prometheus.increment_gauge(name, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `labels` (table): A Lua table containing label key-value pairs

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "http_client_concurrent_requests_total"

nauthilus_prometheus.increment_gauge(name, { service = "some_service_name" })
```

### nauthilus\_prometheus.decrement\_gauge

Decrements a gauge counter by 1 with specified labels.

#### Syntax

```lua
nauthilus_prometheus.decrement_gauge(name, labels)
```

#### Parameters

- `name` (string): The name of the gauge vector
- `labels` (table): A Lua table containing label key-value pairs

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "http_client_concurrent_requests_total"

nauthilus_prometheus.decrement_gauge(name, { service = "some_service_name" })
```

---

## Counter vector

You must create a counter vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_counter\_vec

Creates a Prometheus counter vector with specified name, help text, and labels.

#### Syntax

```lua
nauthilus_prometheus.create_counter_vec(name, help, labels)
```

#### Parameters

- `name` (string): The name of the counter vector
- `help` (string): Description text for the counter vector
- `labels` (table): A Lua table containing label names

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_name"
local help = "Some description for this counter vector"
local labels = { "some_label"}

nauthilus_prometheus.create_counter_vec(name, help, labels)
```

### nauthilus\_prometheus.increment\_counter

Increments a counter by 1 with specified labels.

#### Syntax

```lua
nauthilus_prometheus.increment_counter(name, labels)
```

#### Parameters

- `name` (string): The name of the counter vector
- `labels` (table): A Lua table containing label values

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_counter_name"
local labels = { "some_label" }

nauthilus_prometheus.increment_counter(name, labels)
```

---

## Summary vector

You must create a summary vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_summary\_vec

Creates a Prometheus summary vector with specified name, help text, and labels.

#### Syntax

```lua
nauthilus_prometheus.create_summary_vec(name, help, labels)
```

#### Parameters

- `name` (string): The name of the summary vector
- `help` (string): Description text for the summary vector
- `labels` (table): A Lua table containing label names

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_name"
local help = "Some description for this summary vector"
local labels = { "some_label"}

nauthilus_prometheus.create_summary_vec(name, help, labels)
```

### nauthilus\_prometheus.start\_summary\_timer

Starts a timer for a summary vector with specified labels.

#### Syntax

```lua
local timer = nauthilus_prometheus.start_summary_timer(name, labels)
```

#### Parameters

- `name` (string): The name of the summary vector
- `labels` (table): A Lua table containing label values

#### Returns

- `timer` (userdata): A timer object that can be passed to stop_timer

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_name"
local labels = { "some_label" }

local user_data_timer = nauthilus_prometheus.start_summary_timer(name, labels)
```

### nauthilus\_prometheus.stop\_timer

Stops a timer and records the elapsed time in the associated vector.

#### Syntax

```lua
nauthilus_prometheus.stop_timer(timer)
```

#### Parameters

- `timer` (userdata): A timer object returned from start_summary_timer or start_histogram_timer

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

-- First start a timer
local name = "some_name"
local labels = { "some_label" }
local user_data_timer = nauthilus_prometheus.start_summary_timer(name, labels)

-- Do some work...

-- Then stop the timer
nauthilus_prometheus.stop_timer(user_data_timer)
```

---

## Histogram vector

You must create a histogram vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_histogram\_vec

Creates a Prometheus histogram vector with specified name, help text, and labels.

#### Syntax

```lua
nauthilus_prometheus.create_histogram_vec(name, help, labels)
```

#### Parameters

- `name` (string): The name of the histogram vector
- `help` (string): Description text for the histogram vector
- `labels` (table): A Lua table containing label names

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_name"
local help = "Some description for this histogram vector"
local labels = { "some_label"}

nauthilus_prometheus.create_histogram_vec(name, help, labels)
```

### nauthilus\_prometheus.start\_histogram\_timer

Starts a timer for a histogram vector with specified labels.

#### Syntax

```lua
local timer = nauthilus_prometheus.start_histogram_timer(name, labels)
```

#### Parameters

- `name` (string): The name of the histogram vector
- `labels` (table): A Lua table containing label values

#### Returns

- `timer` (userdata): A timer object that can be passed to stop_timer

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

local name = "some_name"
local labels = { "some_label" }

local user_data_timer = nauthilus_prometheus.start_histogram_timer(name, labels)
```

### nauthilus\_prometheus.stop\_timer

Stops a histogram timer and records the elapsed time in the associated vector.

#### Syntax

```lua
nauthilus_prometheus.stop_timer(timer)
```

#### Parameters

- `timer` (userdata): A timer object returned from start_histogram_timer

#### Returns

None

#### Example

```lua
local nauthilus_prometheus = require("nauthilus_prometheus")

-- First start a timer
local name = "some_name"
local labels = { "some_label" }
local user_data_timer = nauthilus_prometheus.start_histogram_timer(name, labels)

-- Do some work...

-- Then stop the timer
nauthilus_prometheus.stop_timer(user_data_timer)
```
