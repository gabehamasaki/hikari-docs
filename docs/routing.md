---
sidebar_position: 2
---

# Routing and Middleware

Hikari provides a powerful and flexible routing system with support for HTTP methods, route parameters, wildcards, and middleware.

## HTTP Methods

Hikari supports these HTTP methods:

```go
app := hikari.New(":8080")

app.GET("/users", getUsersHandler)
app.POST("/users", createUserHandler)
app.PUT("/users/:id", updateUserHandler)
app.PATCH("/users/:id", patchUserHandler)
app.DELETE("/users/:id", deleteUserHandler)
```

## Route Parameters

### Dynamic Parameters

Use `:param` syntax for dynamic route segments:

```go
app.GET("/users/:id", func(c *hikari.Context) {
    userID := c.Param("id")
    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
    })
})

app.GET("/posts/:category/:id", func(c *hikari.Context) {
    category := c.Param("category")
    postID := c.Param("id")
    c.JSON(http.StatusOK, hikari.H{
        "category": category,
        "post_id": postID,
    })
})
```

### Wildcard Parameters

Use `*` for wildcard matching:

```go
app.GET("/files/*", func(c *hikari.Context) {
    filepath := c.Wildcard()
    c.String(http.StatusOK, "File path: %s", filepath)
})
```

## Route Groups

Organize related routes with shared prefixes and middleware:

```go
// API v1 group
v1 := app.Group("/api/v1")
{
    // Users routes
    users := v1.Group("/users")
    {
        users.GET("/", listUsers)
        users.POST("/", createUser)
        users.GET("/:id", getUser)
        users.PUT("/:id", updateUser)
        users.DELETE("/:id", deleteUser)
    }

    // Posts routes
    posts := v1.Group("/posts")
    {
        posts.GET("/", listPosts)
        posts.POST("/", createPost)
        posts.GET("/:id", getPost)
    }
}

// API v2 group
v2 := app.Group("/api/v2")
{
    v2.GET("/users", listUsersV2)
}
```

## Middleware

Hikari supports three levels of middleware: global, group-level, and route-level.

### Global Middleware

Applied to all routes:

```go
app := hikari.New(":8080")

// Global middleware
app.Use(corsMiddleware)
app.Use(loggingMiddleware)
```

### Group Middleware

Applied to all routes within a group:

```go
// Protected API routes
api := app.Group("/api", authMiddleware, rateLimitMiddleware)
{
    api.GET("/profile", getProfile)
    api.POST("/posts", createPost)
}
```

### Route-Level Middleware

Applied to specific routes:

```go
// Multiple middleware on a single route
app.POST("/admin/users",
    createUserHandler,
    authMiddleware,
    adminMiddleware,
    auditMiddleware,
)
```

## Middleware Examples

### CORS Middleware

```go
func corsMiddleware(c *hikari.Context) {
    c.SetHeader("Access-Control-Allow-Origin", "*")
    c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

    if c.Method() == "OPTIONS" {
        c.Status(http.StatusOK)
        return
    }
}
```

### Authentication Middleware

```go
func authMiddleware(c *hikari.Context) {
    token := c.GetHeader("Authorization")
    if token == "" {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Authorization header required",
        })
        return
    }

    // Validate token and set user context
    userID, err := validateToken(token)
    if err != nil {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Invalid token",
        })
        return
    }

    c.Set("user_id", userID)
}
```

### Rate Limiting Middleware

```go
func rateLimitMiddleware(c *hikari.Context) {
    // Implement rate limiting logic
    clientIP := c.Request.RemoteAddr
    if isRateLimited(clientIP) {
        c.JSON(http.StatusTooManyRequests, hikari.H{
            "error": "Rate limit exceeded",
        })
        return
    }
}
```

## File Serving

Serve static files using wildcard routes and the File method:

```go
// Serve files from ./static directory
app.GET("/static/*", func(c *hikari.Context) {
    filepath := c.Wildcard()
    c.File("./static/" + filepath)
})

// Serve a single file
app.GET("/favicon.ico", func(c *hikari.Context) {
    c.File("./static/favicon.ico")
})
```

## Route Pattern Normalization

Hikari automatically normalizes route patterns:

```go
// These are equivalent:
app.GET("/users/", handler)     // Normalized to "/users"
app.GET("/users", handler)

app.GET("//api//v1//users//", handler)  // Normalized to "/api/v1/users"
```
