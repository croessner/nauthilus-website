---
title: Prometheus
description: Prometheus functions for gauges, counter and histograms
keywords: [Lua]
sidebar_position: 10
---
# Prometheus

Nauthilus has basic support for some Prometheus metrics.

```lua
dynamic_loader("nauthilus_prometheus")
local nauthilus_prometheus = require("nauthilus_prometheus")
```

## Gauge vector

You must create a gauge vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_gauge\_vec

Create a gauge vec

```lua
local name = "http_client_concurrent_requests_total"
local help = "Measure the number of total concurrent HTTP client requests"
local labels = { "service" }

nauthilus_prometheus.create_gauge_vec(name, help, labels)
```

### nauthilus\_prometheus.add\_gauge

Add a value to some gauge with labels

```lua
local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.add_gauge(name, value, labels)
```

### nauthilus\_prometheus.sub\_gauge

Substract a value from some gauge with labels

```lua
local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.sub_gauge(name, value, labels)
```

### nauthilus\_prometheus.set\_gauge

Set a value to some gauge with labels

```lua
local name = "some_gauge_name"
local value = 42
local labels = { "some label" }

nauthilus_prometheus.set_gauge(name, value, labels)
```

### nauthilus\_prometheus.increment\_gauge

Increment a gauge counter

```lua
local name = "http_client_concurrent_requests_total"

nauthilus_prometheus.increment_gauge(name, { service = "some_service_name" })
```

### nauthilus\_prometheus.decrement\_gauge

Decrement a gauge counter

```lua
local name = "http_client_concurrent_requests_total"

nauthilus_prometheus.decrement_gauge(name, { service = "some_service_name" })
```

---

## Counter vector

You must create a counter vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_counter\_vec

Create a counter vec

```lua
local name = "some_name"
local help = "Some description for this summary vector"
local labels = { "some_label"}

nauthilus_prometheus.create_counter_vec(name, help, labels)
```

### nauthilus\_prometheus.increment\_counter

Increment a counter by its labels

```lua
local name = "some_counter_name"
local labels = { "some_label" }

nauthilus_prometheus.increment_counter(name, labels)
```

---

## Summary vector

You must create a summary vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create_summary_vec

Create a summary vec

```lua
local name = "some_name"
local help = "Some description for this summary vector"
local labels = { "some_label"}

nauthilus_prometheus.create_summary_vec(name, help, labels)
```

### nauthilus\_prometheus.start\_summary\_timer

Start a summary timer

```lua
local name = "some_name"
local labels = { "some_label" }

local user_data_timer = nauthilus.prometheus.start_summary_timer(name, labels)
```

### nauthilus\_prometheus.stop\_timer

Stop a summary timer

```lua
local user_data_timer -- From a start_summary_timer-call

nauthilus_prometheus.stop_timer(user_data_timer)
```

---

## Histogram vector

You must create a histogram vector first before using it. This should be done in an init script.

### nauthilus\_prometheus.create\_histogram\_vec

Create a histogram vec

```lua
local name = "some_name"
local help = "Some description for this summary vector"
local labels = { "some_label"}

nauthilus_prometheus.create_histogram_vec(name, help, labels)
```

### nauthilus\_prometheus.start\_histogram\_timer

Start a histogram timer

```lua
local name = "some_name"
local labels = { "some_label" }

local user_data_timer = nauthilus.prometheus.start_histogram_timer(name, labels)
```

### nauthilus\_prometheus.stop\_timer

Stop a histogram timer

```lua
local user_data_timer -- From a start_histogram_timer-call

nauthilus_prometheus.stop_timer(user_data_timer)
```
