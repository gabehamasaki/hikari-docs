---
slug: introducing-hikari
title: Introducing Hikari 🌅 - A New Go Web Framework
authors: [gabe]
tags: [go, web-framework, hikari, performance]
---

# Introducing Hikari 🌅

**Hikari** (光 - "light" in Japanese) is a lightweight, fast, and elegant HTTP web framework for Go that I've been working on. It combines the simplicity developers love with the power needed for modern web applications.

<!--truncate-->

## Why Another Go Framework?

While Go has excellent built-in HTTP capabilities and many great frameworks, I wanted to create something that:

- **Stays lightweight** - No bloat, just what you need
- **Provides excellent DX** - Developer experience should be smooth and intuitive  
- **Includes essentials** - Logging, recovery, and graceful shutdown out of the box
- **Supports modern patterns** - Route groups, middleware, and rich context

## Key Features

### 🚀 Performance First
Hikari is built for speed with minimal overhead. It leverages Go's excellent HTTP performance while adding just the essentials.

### 🛡️ Production Ready
Built-in panic recovery, structured logging with Zap, and graceful shutdown handling mean your apps stay running smoothly.

### 🏗️ Clean Organization
Route groups help you organize your API endpoints logically:

```go
api := app.Group("/api/v1")
{
    users := api.Group("/users")
    {
        users.GET("/", listUsers)
        users.POST("/", createUser)
        users.GET("/:id", getUser)
    }
}
```

### 🧩 Flexible Middleware
Three levels of middleware support (global, group, and route-level) give you complete control:

```go
// Global middleware
app.Use(corsMiddleware, loggingMiddleware)

// Group middleware  
admin := app.Group("/admin", authMiddleware, adminMiddleware)

// Route-level middleware
app.POST("/users", createUser, validationMiddleware, auditMiddleware)
```

### 🎯 Rich Context
The Hikari Context provides everything you need for request handling:

```go
func handler(c *hikari.Context) {
    // URL parameters
    userID := c.Param("id")
    
    // Query parameters  
    page := c.Query("page")
    
    // JSON binding
    var user User
    c.Bind(&user)
    
    // Context storage
    c.Set("user_id", userID)
    
    // JSON response
    c.JSON(http.StatusOK, hikari.H{
        "message": "Success",
        "user": user,
    })
}
```

## Getting Started

Installation is simple:

```bash
go mod init your-project
go get github.com/gabehamasaki/hikari-go
```

A basic "Hello World" server:

```go
package main

import (
    "net/http"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    app.GET("/", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "message": "Hello, World!",
        })
    })

    app.ListenAndServe()
}
```

## What's Next?

I'm actively working on Hikari and have several exciting features planned:

- **WebSocket support** - Real-time communication made easy
- **Built-in validation** - Request validation with custom rules
- **Template rendering** - HTML template support for web applications
- **Advanced middleware** - Rate limiting, caching, and more
- **CLI tools** - Project scaffolding and development tools

## Try It Out!

Check out the [examples](https://github.com/gabehamasaki/hikari-go/tree/main/examples) to see Hikari in action, or dive into the [documentation](/docs/intro) to get started.

I'd love to hear your feedback! Open an issue on [GitHub](https://github.com/gabehamasaki/hikari-go) or start a discussion.

---

*Hikari means "light" in Japanese, representing the framework's goal to be a bright, fast, and illuminating tool for Go developers.*
