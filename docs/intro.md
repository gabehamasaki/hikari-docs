---
sidebar_position: 1
---

# Getting Started

**Hikari** (光 - "light" in Japanese) is a lightweight, fast, and elegant HTTP web framework for Go. It provides a minimalistic yet powerful foundation for building modern web applications and APIs with built-in logging, recovery, and graceful shutdown capabilities.

## ✨ Features

- 🚀 **Lightweight and Fast** - Minimal overhead with maximum performance
- 🛡️ **Built-in Recovery** - Automatic panic recovery to prevent crashes
- 📝 **Structured Logging** - Beautiful colored logs with Uber's Zap logger
- 🏗️ **Route Groups** - Organize routes with shared prefixes and middleware
- 🔗 **Route Parameters** - Support for dynamic route parameters (`:param`) and wildcards (`*`)
- 🧩 **Middleware Support** - Extensible middleware system (global, group, and per-route)
- 🎯 **Context-based** - Rich context with JSON binding, query params, storage, and Go context interface
- 🛑 **Graceful Shutdown** - Proper server shutdown handling with signals
- 📊 **Request Logging** - Automatic contextual logging with timing and User-Agent
- 📁 **File Server** - Serve static files using wildcard routes
- ⚙️ **Configured Timeouts** - Pre-configured read/write timeouts (5s) and configurable request timeouts
- 💾 **Context Storage** - Built-in key-value storage system with thread-safe access
- ⏱️ **Context Management** - Full Go context.Context interface support with cancellation and timeouts
- 🔄 **Pattern Normalization** - Automatic route pattern cleanup and validation
- 🎯 **API Versioning** - Built-in support for organized API structures

## 🚀 Installation

Create a new Go module and install Hikari:

```bash
go mod init your-project
go get github.com/gabehamasaki/hikari-go
```

## 🎯 Quick Example

Here's a simple example to get you started:

```go
package main

import (
    "net/http"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // API v1 group
    v1Group := app.Group("/api/v1")
    {
        v1Group.GET("/hello/:name", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "message": "Hello, " + c.Param("name") + "!",
                "status":  "success",
            })
        })

        // Health check
        v1Group.GET("/health", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "status": "healthy",
                "service": "my-api",
            })
        })
    }

    app.ListenAndServe()
}
```

Run your application:

```bash
go run main.go
```

Visit `http://localhost:8080/api/v1/hello/world` to see your app in action!

## 🏗️ What's Next?

- Learn about [routing and middleware](./routing)
- Explore the [API reference](./api)
- Check out practical [examples](./examples)
- Understand [context management](./context)
